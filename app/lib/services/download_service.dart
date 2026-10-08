import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data.dart';
import '../src/rust/api/proxy.dart';
import 'api_service.dart';
import 'app_paths.dart';
import 'download_transfer.dart';
import 'media_tree.dart';
import 'settings_store.dart';

const _libraryKey = 'voice_downloads';
const _maxConcurrentDownloads = 2;

enum VoiceDownloadStatus { queued, downloading, paused, completed, failed }

class VoiceDownload {
  final String id;
  final String server;
  String voiceRoot;
  final Work work;
  final List<MediaNode> tree;
  final Set<String> selectedPaths;
  final Set<String> pausedPaths;
  final Map<String, int> fileSizes;
  VoiceDownloadStatus status;
  int downloadedBytes;
  int totalBytes;
  String? error;
  String? currentPath;
  int currentFileDownloaded;
  int currentFileTotal;
  DateTime updatedAt;
  MediaTreeIndex? _treeIndex;
  List<MediaNode>? _audioNodes;
  List<MediaNode> _selectedFiles = const [];
  List<MediaNode> _selectedAudio = const [];
  int _selectedVersion = -1;

  void _invalidateTreeIndex() {
    _treeIndex = null;
    _audioNodes = null;
    _selectedVersion = -1;
  }

  VoiceDownload({
    required this.id,
    required this.server,
    required this.voiceRoot,
    required this.work,
    required this.tree,
    required Set<String> selectedPaths,
    this.pausedPaths = const <String>{},
    this.fileSizes = const <String, int>{},
    this.status = VoiceDownloadStatus.queued,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
    this.currentPath,
    this.currentFileDownloaded = 0,
    this.currentFileTotal = 0,
    DateTime? updatedAt,
  }) : selectedPaths = _VersionedPaths(selectedPaths),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'server': server,
    'voiceRoot': voiceRoot,
    'work': _workToJson(work),
    'tree': _nodesToJson(tree),
    'selectedPaths': selectedPaths.toList(),
    'pausedPaths': pausedPaths.toList(),
    'fileSizes': fileSizes,
    'status': status.name,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'error': error,
    'currentPath': currentPath,
    'currentFileDownloaded': currentFileDownloaded,
    'currentFileTotal': currentFileTotal,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory VoiceDownload.fromJson(Map<String, dynamic> json) {
    final rawWork = json['work'];
    final rawTree = json['tree'];
    final statusName = json['status'] as String?;
    return VoiceDownload(
      id: json['id'] as String,
      server: json['server'] as String,
      voiceRoot: json['voiceRoot'] as String,
      work: _workFromJson(rawWork as Map<String, dynamic>),
      tree: _nodesFromJson(rawTree as List? ?? const []),
      selectedPaths:
          ((json['selectedPaths'] as List?) ??
                  (json['requestedPaths'] as List?) ??
                  const [])
              .map((e) => e.toString())
              .toSet(),
      pausedPaths: ((json['pausedPaths'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      fileSizes: ((json['fileSizes'] as Map?) ?? const {}).map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      status: VoiceDownloadStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => VoiceDownloadStatus.queued,
      ),
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
      currentPath: json['currentPath'] as String?,
      currentFileDownloaded:
          (json['currentFileDownloaded'] as num?)?.toInt() ?? 0,
      currentFileTotal: (json['currentFileTotal'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class DownloadManager extends ChangeNotifier {
  DownloadManager._({
    Future<String> Function()? voiceDirectory,
    String? Function(String)? readSetting,
    void Function(String, String)? writeSetting,
    String Function(String)? proxyUrl,
    this._progressPersistInterval = const Duration(seconds: 5),
  }) : _voiceDirectory = voiceDirectory ?? AppPaths.voiceDir,
       _readSetting = readSetting ?? SettingsStore.get,
       _writeSetting = writeSetting ?? SettingsStore.set,
       _proxyUrl = proxyUrl ?? ((url) => apiStreamProxyUrl(url: url));

  @visibleForTesting
  factory DownloadManager.forTesting({
    required String voiceRoot,
    required void Function(String key, String value) writeSetting,
    String? Function(String key)? readSetting,
    Duration progressPersistInterval = const Duration(seconds: 5),
  }) => DownloadManager._(
    voiceDirectory: () async => voiceRoot,
    readSetting: readSetting ?? (_) => null,
    writeSetting: writeSetting,
    proxyUrl: (url) => url,
    progressPersistInterval: progressPersistInterval,
  );

  static final instance = DownloadManager._();

  final List<VoiceDownload> _downloads = [];
  final Map<String, Future<void>> _running = {};
  final Map<String, HttpClientRequest> _requests = {};
  final Map<String, void Function()> _transferCancels = {};
  final Map<String, Future<void>> _reconciliations = {};
  final Set<String> _deleting = {};
  final Set<String> _cancelled = {};
  final Map<String, Map<String, int>> _completedFiles = {};
  final Future<String> Function() _voiceDirectory;
  final String? Function(String) _readSetting;
  final void Function(String, String) _writeSetting;
  final String Function(String) _proxyUrl;
  final Duration _progressPersistInterval;
  Timer? _progressPersistTimer;
  bool _progressDirty = false;
  bool _disposed = false;
  bool _ready = false;
  bool _persisting = false;

  List<VoiceDownload> get downloads => List.unmodifiable(_downloads);

  Future<void> init() async {
    if (_ready) return;
    final root = await _voiceDirectory();
    final raw = _readSetting(_libraryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          try {
            final download = VoiceDownload.fromJson(
              item as Map<String, dynamic>,
            );
            if (download.status == VoiceDownloadStatus.downloading) {
              download.status = VoiceDownloadStatus.queued;
            }
            await _moveToCurrentVoiceRoot(download, root);
            _normalizeItemPaths(download);
            download.voiceRoot = root;
            await _refreshCompletedFiles(download);
            if (download.status == VoiceDownloadStatus.completed) {
              final missing = selectedFiles(download)
                  .where((node) => !isDownloaded(download, node))
                  .map((node) => node.path)
                  .toList();
              if (missing.isNotEmpty) {
                download.status = VoiceDownloadStatus.paused;
                download.pausedPaths.addAll(missing);
              }
            }
            _downloads.add(download);
          } catch (_) {
            // Ignore a single corrupt entry and keep the remaining library.
          }
        }
      } catch (_) {
        _writeSetting(_libraryKey, '[]');
      }
    }
    _ready = true;
    await _persist();
    _pump();
  }

  Future<void> _moveToCurrentVoiceRoot(
    VoiceDownload item,
    String currentRoot,
  ) async {
    final folder = _safePart('${item.work.rj} ${item.work.title}');
    final newDir = Directory('$currentRoot${Platform.pathSeparator}$folder');
    if (item.voiceRoot != currentRoot) {
      final oldDir = Directory(
        '${item.voiceRoot}${Platform.pathSeparator}$folder',
      );
      if (await oldDir.exists() && !await newDir.exists()) {
        try {
          await oldDir.rename(newDir.path);
        } catch (_) {
          // A locked old directory should not prevent the library from loading.
        }
      }
    }
    await _flattenLegacyTreeRoot(item, newDir);
  }

  Future<void> _flattenLegacyTreeRoot(
    VoiceDownload item,
    Directory workDir,
  ) async {
    if (!await workDir.exists() ||
        item.tree.length != 1 ||
        !item.tree.first.isDir) {
      return;
    }
    final wrapper = Directory(
      '${workDir.path}${Platform.pathSeparator}${_safePart(item.tree.first.title)}',
    );
    if (!await wrapper.exists()) return;
    try {
      for (final child in await wrapper.list().toList()) {
        final name = child.uri.pathSegments.last;
        final target = '${workDir.path}${Platform.pathSeparator}$name';
        if (!await FileSystemEntity.type(
          target,
        ).then((type) => type != FileSystemEntityType.notFound)) {
          await child.rename(target);
        }
      }
      if ((await wrapper.list().toList()).isEmpty) await wrapper.delete();
    } catch (_) {
      // Best effort migration. Existing files stay accessible in the old shape.
    }
  }

  Future<void> enqueue({
    required AppState app,
    required Work work,
    required List<MediaNode> tree,
    required Set<String> selectedPaths,
  }) async {
    if (!_ready) await init();
    final server = ApiService.resolveBase(app).replaceFirst(RegExp(r'/+$'), '');
    final id = '$server|${work.rj}';
    final root = await _voiceDirectory();
    var item = _find(id);
    final normalizedTree = normalizeDownloadTree(tree);
    final normalizedPaths = normalizeDownloadSelectionPaths(
      selectedPaths,
      tree,
    );
    if (item == null) {
      item = VoiceDownload(
        id: id,
        server: server,
        voiceRoot: root,
        work: work,
        tree: List.of(normalizedTree),
        selectedPaths: <String>{},
        pausedPaths: <String>{},
        fileSizes: <String, int>{},
      );
      _downloads.insert(0, item);
    } else {
      final mergedTree = mergeDownloadTrees(item.tree, normalizedTree);
      item.tree
        ..clear()
        ..addAll(mergedTree);
    }
    item._invalidateTreeIndex();
    item.selectedPaths.addAll(normalizedPaths);
    await _refreshCompletedFiles(item);
    item.status = VoiceDownloadStatus.queued;
    item.error = null;
    item.updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
    _pump();
  }

  void cancel(String id) {
    final item = _find(id);
    if (item == null) return;
    _cancelled.add(id);
    _abortTransfer(id);
    item.status = VoiceDownloadStatus.queued;
    item.updatedAt = DateTime.now();
    unawaited(_persistAndNotify());
  }

  void toggleFile(VoiceDownload item, MediaNode node) {
    if (isDownloaded(item, node) || node.isDir) return;
    if (item.pausedPaths.remove(node.path)) {
      _resumeWithRefresh(item);
      return;
    }
    item.pausedPaths.add(node.path);
    if (item.currentPath == node.path) {
      _cancelled.add(item.id);
      _abortTransfer(item.id);
    }
    if (item.status != VoiceDownloadStatus.downloading) {
      item.status = VoiceDownloadStatus.paused;
    }
    unawaited(_persistAndNotify());
  }

  void toggleAll() {
    final active = _downloads.any(
      (item) =>
          item.status == VoiceDownloadStatus.downloading ||
          item.status == VoiceDownloadStatus.queued,
    );
    if (active) {
      for (final item in _downloads) {
        for (final node in selectedFiles(item)) {
          if (!isDownloaded(item, node)) item.pausedPaths.add(node.path);
        }
        if (item.currentPath != null) {
          _cancelled.add(item.id);
          _abortTransfer(item.id);
        }
        if (item.status != VoiceDownloadStatus.completed) {
          item.status = VoiceDownloadStatus.paused;
        }
      }
    } else {
      for (final item in _downloads) {
        item.pausedPaths.clear();
        if (selectedFiles(item).isNotEmpty) _resumeWithRefresh(item);
      }
    }
    unawaited(_persistAndNotify());
  }

  Future<void> removeFileRecords(Map<String, Set<String>> selected) async {
    for (final entry in selected.entries) {
      final item = _find(entry.key);
      if (item == null) continue;
      if (item.currentPath != null && entry.value.contains(item.currentPath)) {
        _cancelled.add(item.id);
        _abortTransfer(item.id);
      }
      final remaining = selectedFiles(item)
          .where((node) => !entry.value.contains(node.path))
          .map((node) => node.path)
          .toSet();
      if (remaining.isEmpty) {
        _cancelled.add(item.id);
        _abortTransfer(item.id);
        if (_hasLocalFiles(item)) {
          // The queue record is gone, but this is still a local-library work.
          // Keep its card and metadata so the downloaded files remain visible.
          item.selectedPaths.clear();
          item.pausedPaths.clear();
          item.status = VoiceDownloadStatus.completed;
          item.error = null;
          item.currentPath = null;
          item.currentFileDownloaded = 0;
          item.currentFileTotal = 0;
        } else {
          _downloads.remove(item);
        }
      } else {
        item.selectedPaths
          ..clear()
          ..addAll(remaining);
        item.pausedPaths.removeWhere((path) => !remaining.contains(path));
      }
    }
    await _persistAndNotify();
  }

  /// Deletes completed local files selected in a work detail view and removes
  /// their download records. Missing files and partial downloads are ignored.
  Future<int> deleteDownloadedFiles(
    VoiceDownload item,
    Set<String> selectedPaths,
  ) async {
    if (selectedPaths.isEmpty || !_downloads.contains(item)) return 0;
    final deleted = <String>{};
    for (final node in treeIndex(item).filesAtPaths(selectedPaths)) {
      if (!isDownloaded(item, node)) continue;
      final file = File(_localPath(item, node));
      try {
        await file.delete();
        deleted.add(node.path);
        item.fileSizes.remove(node.path);
        _completedFiles[item.id]?.remove(node.path);
      } catch (_) {
        // Continue deleting the remaining selected files when one is locked.
      }
    }
    if (deleted.isEmpty) return 0;

    final remaining = selectedFiles(item)
        .where((node) => !deleted.contains(node.path))
        .map((node) => node.path)
        .toSet();
    if (remaining.isEmpty) {
      item.selectedPaths.clear();
      item.pausedPaths.clear();
      item.status = VoiceDownloadStatus.completed;
      item.error = null;
    } else {
      item.selectedPaths
        ..clear()
        ..addAll(remaining);
      item.pausedPaths.removeWhere((path) => !remaining.contains(path));
    }
    item.downloadedBytes = _completedBytes(item);
    item.totalBytes = item.fileSizes.values.fold(0, (sum, size) => sum + size);
    item.updatedAt = DateTime.now();
    await _persistAndNotify();
    return deleted.length;
  }

  Future<void> deleteWorks(Set<String> ids) async {
    final targets = _downloads.where((item) => ids.contains(item.id)).toList();
    for (final item in targets) {
      _deleting.add(item.id);
      _cancelled.add(item.id);
      _abortTransfer(item.id);
      try {
        // Close the partial file before deleting its directory, including on
        // platforms that refuse to delete an open RandomAccessFile.
        await _running[item.id];
        await _reconciliations[item.id];
        final folder = Directory(_workDirectory(item));
        if (await folder.exists()) {
          try {
            await folder.delete(recursive: true);
          } catch (_) {
            // Keep the record if the file system refuses the requested delete.
            continue;
          }
        }
        _downloads.remove(item);
        _completedFiles.remove(item.id);
      } finally {
        _deleting.remove(item.id);
        _cancelled.remove(item.id);
      }
    }
    await _persistAndNotify();
    _pump();
  }

  void retry(String id) {
    final item = _find(id);
    if (item != null) _resumeWithRefresh(item);
  }

  void _abortTransfer(String id) {
    _requests[id]?.abort();
    _transferCancels[id]?.call();
  }

  void _resumeWithRefresh(VoiceDownload item) {
    if (_disposed || !_downloads.contains(item)) return;
    if (item.status != VoiceDownloadStatus.downloading) {
      item.status = VoiceDownloadStatus.queued;
    }
    item.error = null;
    item.updatedAt = DateTime.now();
    // Consecutive controls share one async scan. Its completion only pumps the
    // latest synchronous status/pausedPaths, so a later pause stays effective.
    if (!_reconciliations.containsKey(item.id)) {
      final refresh = _refreshCompletedFiles(item);
      _reconciliations[item.id] = refresh;
      unawaited(_finishReconciliation(item, refresh));
    }
    unawaited(_persistAndNotify());
  }

  Future<void> _finishReconciliation(
    VoiceDownload item,
    Future<void> refresh,
  ) async {
    try {
      await refresh;
    } catch (error) {
      if (!_disposed &&
          _downloads.contains(item) &&
          item.status == VoiceDownloadStatus.queued) {
        item.status = VoiceDownloadStatus.failed;
        item.error = error.toString();
      }
    } finally {
      if (identical(_reconciliations[item.id], refresh)) {
        _reconciliations.remove(item.id);
      }
    }
    if (_disposed) return;
    if (_downloads.contains(item)) await _persistAndNotify();
    _pump();
  }

  String? localPathFor({
    required String server,
    required Work work,
    required MediaNode node,
  }) {
    final normalizedServer = server.replaceFirst(RegExp(r'/+$'), '');
    final item = _find('$normalizedServer|${work.rj}');
    if (item == null || !isAudioNode(node)) return null;
    final file = File(_localPath(item, node));
    // Playback checks once at the user action boundary; list builds use the
    // cached completion state instead of synchronously probing every file.
    if (!isDownloaded(item, node)) return null;
    if (file.existsSync()) return file.path;
    _completedFiles[item.id]?.remove(node.path);
    return null;
  }

  String localPath(VoiceDownload item, MediaNode node) =>
      _localPath(item, node);

  bool isDownloaded(VoiceDownload item, MediaNode node) {
    if (node.isDir) return false;
    return (_completedFiles[item.id]?[node.path] ?? 0) > 0;
  }

  MediaTreeIndex treeIndex(VoiceDownload item) =>
      item._treeIndex ??= MediaTreeIndex(item.tree);

  List<MediaNode> audioNodes(VoiceDownload item) => item._audioNodes ??=
      List.unmodifiable(treeIndex(item).files.where(isAudioNode));

  void _syncSelectedFiles(VoiceDownload item) {
    final version = (item.selectedPaths as _VersionedPaths).version;
    if (item._selectedVersion == version) return;
    final selected = treeIndex(item).filesAtPaths(item.selectedPaths);
    item._selectedFiles = List.unmodifiable(
      selected.where(
        (node) => (node.downloadUrl ?? node.url)?.isNotEmpty == true,
      ),
    );
    item._selectedAudio = List.unmodifiable(selected.where(isAudioNode));
    item._selectedVersion = version;
  }

  List<MediaNode> selectedAudioNodes(VoiceDownload item) {
    _syncSelectedFiles(item);
    return item._selectedAudio;
  }

  List<MediaNode> selectedFiles(VoiceDownload item) {
    _syncSelectedFiles(item);
    return item._selectedFiles;
  }

  /// Download-file groups only include works that still have file records.
  /// Local-library metadata may remain after the last record is removed, but
  /// it must not render as an empty group here.
  List<VoiceDownload> get recordItems =>
      _downloads.where((item) => selectedFiles(item).isNotEmpty).toList();

  bool isSelected(VoiceDownload item, MediaNode node) =>
      _isSelected(item, node.path);

  VoiceDownload? get activeDownload {
    for (final item in _downloads) {
      if (item.status == VoiceDownloadStatus.downloading) return item;
    }
    for (final item in _downloads) {
      if (item.status == VoiceDownloadStatus.queued) return item;
    }
    return null;
  }

  double get activeProgress {
    final item = activeDownload;
    if (item == null || item.currentFileTotal <= 0) return 0;
    return (item.currentFileDownloaded / item.currentFileTotal)
        .clamp(0, 1)
        .toDouble();
  }

  VoiceDownload? _find(String id) {
    for (final item in _downloads) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _pump() {
    if (!_ready || _disposed) return;
    while (_running.length < _maxConcurrentDownloads) {
      VoiceDownload? next;
      for (final item in _downloads) {
        if (item.status == VoiceDownloadStatus.queued &&
            !_running.containsKey(item.id) &&
            !_reconciliations.containsKey(item.id) &&
            !_deleting.contains(item.id)) {
          next = item;
          break;
        }
      }
      if (next == null) break;
      final item = next;
      final future = _run(item);
      _running[item.id] = future;
      unawaited(
        future.whenComplete(() {
          _running.remove(item.id);
          _pump();
        }),
      );
    }
  }

  Future<void> _run(VoiceDownload item) async {
    item.status = VoiceDownloadStatus.downloading;
    item.error = null;
    item.updatedAt = DateTime.now();
    await _persistAndNotify();
    try {
      if (selectedFiles(item).isEmpty) throw StateError('没有可下载的文件');
      while (true) {
        // A later file may have been resumed during the previous transfer.
        // Wait for that action's disk snapshot before choosing the next file.
        await _reconciliations[item.id];
        if (_cancelled.contains(item.id) || !_downloads.contains(item)) {
          throw const _DownloadCancelled();
        }
        // Re-read the live selection after every transfer. This also includes
        // files resumed or added while an earlier file was still downloading.
        MediaNode? next;
        for (final node in selectedFiles(item)) {
          if (!isDownloaded(item, node) &&
              !item.pausedPaths.contains(node.path)) {
            next = node;
            break;
          }
        }
        if (next == null) break;
        final node = next;
        final url = node.downloadUrl ?? node.url;
        if (url == null || url.isEmpty) throw StateError('下载文件地址为空');
        item.currentPath = node.path;
        item.currentFileDownloaded = 0;
        item.currentFileTotal = item.fileSizes[node.path] ?? 0;
        await _persistAndNotify();
        await _downloadFile(item, node, url);
      }
      final pending = selectedFiles(
        item,
      ).any((node) => !isDownloaded(item, node));
      item.currentPath = null;
      item.currentFileDownloaded = 0;
      item.currentFileTotal = 0;
      item.status = pending
          ? VoiceDownloadStatus.paused
          : VoiceDownloadStatus.completed;
      item.updatedAt = DateTime.now();
      await _persistAndNotify();
    } on _DownloadCancelled {
      _cancelled.remove(item.id);
      final remaining = selectedFiles(item);
      final runnable = remaining.any(
        (node) =>
            !isDownloaded(item, node) && !item.pausedPaths.contains(node.path),
      );
      item.status =
          _deleting.contains(item.id) ||
              item.status == VoiceDownloadStatus.paused
          ? VoiceDownloadStatus.paused
          : remaining.isEmpty && _hasLocalFiles(item)
          ? VoiceDownloadStatus.completed
          : runnable
          ? VoiceDownloadStatus.queued
          : VoiceDownloadStatus.paused;
      item.currentPath = null;
      item.currentFileDownloaded = 0;
      item.currentFileTotal = 0;
      item.updatedAt = DateTime.now();
      await _persistAndNotify();
    } catch (e) {
      if (_cancelled.remove(item.id)) {
        if (item.status != VoiceDownloadStatus.paused) {
          item.status = VoiceDownloadStatus.queued;
        }
      } else {
        item.status = VoiceDownloadStatus.failed;
        item.error = e.toString();
      }
      item.currentPath = null;
      item.currentFileDownloaded = 0;
      item.currentFileTotal = 0;
      item.updatedAt = DateTime.now();
      await _persistAndNotify();
    }
  }

  Future<void> _downloadFile(
    VoiceDownload item,
    MediaNode node,
    String url,
  ) async {
    final target = File(_localPath(item, node));
    final completedBytes = _completedBytes(item);
    var lastUpdate = DateTime.now();
    bool isCancelled() =>
        _disposed ||
        _cancelled.contains(item.id) ||
        !_downloads.contains(item) ||
        !_isSelected(item, node.path) ||
        item.pausedPaths.contains(node.path);
    try {
      await downloadToFile(
        uri: Uri.parse(_proxyUrl(url)),
        sourceUrl: url,
        target: target,
        isCancelled: isCancelled,
        onCancel: (cancel) {
          if (cancel == null) {
            _transferCancels.remove(item.id);
          } else {
            _transferCancels[item.id] = cancel;
            if (isCancelled()) cancel();
          }
        },
        onRequest: (request) {
          if (request == null) {
            _requests.remove(item.id);
          } else {
            _requests[item.id] = request;
            if (isCancelled()) request.abort();
          }
        },
        onProgress: (received, total) {
          if (_disposed) return;
          item.currentFileDownloaded = received;
          item.currentFileTotal = total;
          item.downloadedBytes = completedBytes + received;
          if (total > 0 && item.fileSizes[node.path] != total) {
            final previousSize = item.fileSizes[node.path] ?? 0;
            item.fileSizes[node.path] = total;
            item.totalBytes += total - previousSize;
          }
          final now = DateTime.now();
          if (now.difference(lastUpdate) >= const Duration(milliseconds: 350)) {
            item.updatedAt = now;
            notifyListeners();
            _scheduleProgressPersist();
            lastUpdate = now;
          }
        },
      );
    } catch (error) {
      if (error is DownloadTransferCancelled || isCancelled()) {
        throw const _DownloadCancelled();
      }
      rethrow;
    }
    final size = await target.length();
    if (size == 0) throw const HttpException('下载文件为空');
    (_completedFiles[item.id] ??= {})[node.path] = size;
    item.downloadedBytes = _completedBytes(item);
    item.updatedAt = DateTime.now();
    await _persistAndNotify();
  }

  /// Reconcile disk state at initialization, structural changes and explicit
  /// resume controls, never on each progress tick or while a list is built.
  Future<void> _refreshCompletedFiles(VoiceDownload item) async {
    final completed = _completedFiles[item.id] ??= {};
    final files = treeIndex(item).files;
    // Bound filesystem work while avoiding one round trip per file at startup.
    for (var start = 0; start < files.length; start += 8) {
      final end = start + 8 < files.length ? start + 8 : files.length;
      await Future.wait(
        files.sublist(start, end).map((node) async {
          final previous = completed[node.path];
          final stat = await File(_localPath(item, node)).stat();
          // A running transfer may have completed while stat was in flight.
          if (completed[node.path] != previous) return;
          final expected = item.fileSizes[node.path];
          if (stat.type == FileSystemEntityType.file &&
              stat.size > 0 &&
              (expected == null || expected == 0 || expected == stat.size)) {
            completed[node.path] = stat.size;
          } else {
            completed.remove(node.path);
          }
        }),
      );
    }
    item.downloadedBytes = _completedBytes(item);
  }

  int _completedBytes(VoiceDownload item) {
    final completed = _completedFiles[item.id];
    if (completed == null) return 0;
    var bytes = 0;
    for (final entry in completed.entries) {
      if (_isSelected(item, entry.key)) bytes += entry.value;
    }
    return bytes;
  }

  bool _hasLocalFiles(VoiceDownload item) =>
      treeIndex(item).files.any((node) => isDownloaded(item, node));

  /// Older records used the API's optional display-only root folder in their
  /// paths. Normalize them after the on-disk migration so later top-level
  /// changes from the API cannot hide already downloaded files.
  void _normalizeItemPaths(VoiceDownload item) {
    final originalTree = List<MediaNode>.from(item.tree);
    final normalizedTree = normalizeDownloadTree(originalTree);
    String normalize(String path) =>
        normalizeDownloadSelectionPaths({path}, originalTree).single;
    final selectedPaths = item.selectedPaths.map(normalize).toSet();
    final pausedPaths = item.pausedPaths.map(normalize).toSet();

    item.tree
      ..clear()
      ..addAll(normalizedTree);
    item.selectedPaths
      ..clear()
      ..addAll(selectedPaths);
    item.pausedPaths
      ..clear()
      ..addAll(pausedPaths);
    item._invalidateTreeIndex();
    final fileSizes = Map<String, int>.from(item.fileSizes);
    item.fileSizes
      ..clear()
      ..addEntries(
        fileSizes.entries.map(
          (entry) => MapEntry(normalize(entry.key), entry.value),
        ),
      );
    if (item.currentPath != null) {
      item.currentPath = normalize(item.currentPath!);
    }
  }

  String _localPath(VoiceDownload item, MediaNode node) {
    final folder = _safePart('${item.work.rj} ${item.work.title}');
    final parts = node.path
        .split('/')
        .where((part) => part.isNotEmpty)
        .map(_safePart)
        .toList();
    return [item.voiceRoot, folder, ...parts].join(Platform.pathSeparator);
  }

  String _workDirectory(VoiceDownload item) =>
      '${item.voiceRoot}${Platform.pathSeparator}${_safePart('${item.work.rj} ${item.work.title}')}';

  bool _isSelected(VoiceDownload item, String path) =>
      mediaPathIsSelected(item.selectedPaths, path);
  void _scheduleProgressPersist() {
    if (_disposed) return;
    _progressDirty = true;
    _progressPersistTimer ??= Timer(_progressPersistInterval, () {
      _progressPersistTimer = null;
      if (_progressDirty && !_disposed) {
        unawaited(
          _persist().catchError((Object error) {
            debugPrint('Failed to save download progress: $error');
          }),
        );
      }
    });
  }

  Future<void> _persistAndNotify() async {
    if (_disposed) return;
    await _persist();
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist() async {
    if (_persisting || _disposed) return;
    _progressPersistTimer?.cancel();
    _progressPersistTimer = null;
    _progressDirty = false;
    _persisting = true;
    try {
      _writeSetting(
        _libraryKey,
        jsonEncode(_downloads.map((item) => item.toJson()).toList()),
      );
    } finally {
      _persisting = false;
    }
  }

  @override
  void dispose() {
    _progressPersistTimer?.cancel();
    if (_progressDirty) {
      // Preserve the last snapshot when an owning test/application shuts down.
      _writeSetting(
        _libraryKey,
        jsonEncode(_downloads.map((item) => item.toJson()).toList()),
      );
    }
    _disposed = true;
    for (final id in {..._requests.keys, ..._transferCancels.keys}) {
      _abortTransfer(id);
    }
    super.dispose();
  }
}

/// Removes the optional single display root returned by some media APIs.
/// Download storage already has a work directory, so retaining that root makes
/// a later API response with a different root name point at a different file.
List<MediaNode> normalizeDownloadTree(List<MediaNode> tree) {
  if (tree.length != 1 || !tree.first.isDir) return tree;
  final rootPath = tree.first.path;
  final prefix = '$rootPath/';
  final index = MediaTreeIndex(tree.first.children);
  final rebased = <MediaNode, MediaNode>{};
  for (final row in index.rows.reversed) {
    final node = row.node;
    rebased[node] = _copyMediaNode(
      node,
      path: node.path.startsWith(prefix)
          ? node.path.substring(prefix.length)
          : node.path,
      children: [for (final child in node.children) rebased[child] ?? child],
    );
  }
  return [for (final node in tree.first.children) rebased[node]!];
}

/// Applies [normalizeDownloadTree]'s path mapping to selections made against
/// the original API tree. Selecting the display root becomes an all-files
/// selection, represented by the empty path.
Set<String> normalizeDownloadSelectionPaths(
  Iterable<String> paths,
  List<MediaNode> tree,
) {
  if (tree.length != 1 || !tree.first.isDir) return paths.toSet();
  final rootPath = tree.first.path;
  final prefix = '$rootPath/';
  return paths.map((path) {
    if (path == rootPath) return '';
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }).toSet();
}

/// Combines a refreshed media tree with the stored tree. Files omitted by a
/// transient or changed API response are retained so their local records and
/// playback paths continue to work; refreshed nodes supply current URLs.
List<MediaNode> mergeDownloadTrees(
  List<MediaNode> stored,
  List<MediaNode> refreshed,
) {
  final stack = [_MergeMediaFrame(stored, refreshed)];
  while (stack.isNotEmpty) {
    final frame = stack.last;
    if (frame.cursor == frame.refreshed.length) {
      frame.merged.addAll(frame.remaining.values);
      stack.removeLast();
      if (stack.isEmpty) return frame.merged;
      stack.last.merged.add(
        _copyMediaNode(frame.parent!, children: frame.merged),
      );
      continue;
    }
    final node = frame.refreshed[frame.cursor++];
    final previous = frame.remaining.remove(node.path);
    if (previous != null && previous.isDir && node.isDir) {
      stack.add(
        _MergeMediaFrame(previous.children, node.children, parent: node),
      );
    } else {
      frame.merged.add(node);
    }
  }
  return const [];
}

MediaNode _copyMediaNode(
  MediaNode node, {
  String? path,
  List<MediaNode>? children,
}) => MediaNode(
  title: node.title,
  type: node.type,
  path: path ?? node.path,
  children: children ?? node.children,
  url: node.url,
  downloadUrl: node.downloadUrl,
  duration: node.duration,
);

class _MergeMediaFrame {
  final List<MediaNode> refreshed;
  final MediaNode? parent;
  final Map<String, MediaNode> remaining;
  final List<MediaNode> merged = [];
  int cursor = 0;
  _MergeMediaFrame(List<MediaNode> stored, this.refreshed, {this.parent})
    : remaining = {for (final node in stored) node.path: node};
}

class _VersionedPaths extends SetBase<String> {
  final Set<String> _paths;
  int version = 0;
  _VersionedPaths(Iterable<String> paths) : _paths = Set.of(paths);
  @override
  int get length => _paths.length;
  @override
  Iterator<String> get iterator => _paths.iterator;
  @override
  Set<String> toSet() => Set.of(_paths);
  @override
  bool contains(Object? value) => _paths.contains(value);
  @override
  String? lookup(Object? value) => _paths.lookup(value);
  @override
  bool add(String value) {
    if (!_paths.add(value)) return false;
    version++;
    return true;
  }

  @override
  bool remove(Object? value) {
    if (!_paths.remove(value)) return false;
    version++;
    return true;
  }

  @override
  void clear() {
    if (_paths.isEmpty) return;
    _paths.clear();
    version++;
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}

bool isAudioNode(MediaNode node) =>
    !node.isDir &&
    RegExp(
      r'\.(mp3|ogg|opus|wav|aac|flac|webm|mp4|m4a|mka|aiff|wma|ape)$',
      caseSensitive: false,
    ).hasMatch(node.title);

String _safePart(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return '_';
  return cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
}

Map<String, dynamic> _workToJson(Work work) => {
  'rj': work.rj,
  'title': work.title,
  'circle': work.circle,
  'va': work.va,
  'age': work.age.index,
  'dur': work.dur,
  'releaseDate': work.releaseDate,
  'tags': work.tags,
  'grayTags': work.grayTags,
  'grad': work.grad,
  'coverUrl': work.coverUrl,
  'hasSubtitle': work.hasSubtitle,
  'apiId': work.apiId,
  'hasReview': work.hasReview,
  'languageEditions': work.languageEditions
      .map(
        (edition) => {
          'id': edition.id,
          'title': edition.title,
          'language': edition.language,
          'isOriginal': edition.isOriginal,
        },
      )
      .toList(),
};

Work _workFromJson(Map<String, dynamic> json) => Work(
  rj: json['rj'] as String? ?? '',
  title: json['title'] as String? ?? '未知作品',
  circle: json['circle'] as String? ?? '',
  va: json['va'] as String? ?? '',
  age: Age.values[(json['age'] as num?)?.toInt().clamp(0, 2) ?? 0],
  dur: json['dur'] as String? ?? '',
  releaseDate: json['releaseDate'] as String? ?? '',
  tags: ((json['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
  grayTags: ((json['grayTags'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList(),
  grad: (json['grad'] as num?)?.toInt() ?? 0,
  coverUrl: json['coverUrl'] as String?,
  hasSubtitle: json['hasSubtitle'] as bool? ?? false,
  apiId: (json['apiId'] as num?)?.toInt(),
  hasReview: json['hasReview'] as bool?,
  languageEditions: ((json['languageEditions'] as List?) ?? const [])
      .whereType<Map>()
      .map(
        (edition) => LanguageEdition(
          id: (edition['id'] as num?)?.toInt() ?? 0,
          title: edition['title'] as String? ?? '',
          language: edition['language'] as String?,
          isOriginal: edition['isOriginal'] as bool? ?? false,
        ),
      )
      .where((edition) => edition.id > 0)
      .toList(),
);

List<Map<String, dynamic>> _nodesToJson(List<MediaNode> nodes) {
  final index = MediaTreeIndex(nodes);
  final encoded = <MediaNode, Map<String, dynamic>>{};
  for (final row in index.rows.reversed) {
    final node = row.node;
    encoded[node] = {
      'title': node.title,
      'type': node.type,
      'path': node.path,
      'children': [for (final child in node.children) encoded[child]!],
      'url': node.url,
      'downloadUrl': node.downloadUrl,
      'duration': node.duration,
    };
  }
  return [for (final node in nodes) encoded[node]!];
}

List<MediaNode> _nodesFromJson(List<dynamic> raw) {
  final stack = [_DecodeMediaFrame(raw)];
  while (stack.isNotEmpty) {
    final frame = stack.last;
    if (frame.cursor == frame.raw.length) {
      stack.removeLast();
      if (stack.isEmpty) return frame.nodes;
      final json = frame.parent!;
      stack.last.nodes.add(
        MediaNode(
          title: json['title'] as String? ?? '',
          type: json['type'] as String? ?? 'file',
          path: json['path'] as String? ?? '',
          children: frame.nodes,
          url: json['url'] as String?,
          downloadUrl: json['downloadUrl'] as String?,
          duration: (json['duration'] as num?)?.toInt() ?? 0,
        ),
      );
      continue;
    }
    final json = frame.raw[frame.cursor++] as Map<String, dynamic>;
    stack.add(
      _DecodeMediaFrame(json['children'] as List? ?? const [], parent: json),
    );
  }
  return const [];
}

class _DecodeMediaFrame {
  final List<dynamic> raw;
  final Map<String, dynamic>? parent;
  final List<MediaNode> nodes = [];
  int cursor = 0;
  _DecodeMediaFrame(this.raw, {this.parent});
}
