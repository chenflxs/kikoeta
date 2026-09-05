import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data.dart';
import '../src/rust/api/proxy.dart';
import 'api_service.dart';
import 'app_paths.dart';
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

  VoiceDownload({
    required this.id,
    required this.server,
    required this.voiceRoot,
    required this.work,
    required this.tree,
    required this.selectedPaths,
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
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'server': server,
    'voiceRoot': voiceRoot,
    'work': _workToJson(work),
    'tree': tree.map(_nodeToJson).toList(),
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
      tree: (rawTree as List? ?? const [])
          .map((e) => _nodeFromJson(e as Map<String, dynamic>))
          .toList(),
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
  DownloadManager._();

  static final instance = DownloadManager._();

  final List<VoiceDownload> _downloads = [];
  final Map<String, Future<void>> _running = {};
  final Map<String, HttpClientRequest> _requests = {};
  final Set<String> _cancelled = {};
  bool _ready = false;
  bool _persisting = false;

  List<VoiceDownload> get downloads => List.unmodifiable(_downloads);

  Future<void> init() async {
    if (_ready) return;
    final root = await AppPaths.voiceDir();
    final raw = SettingsStore.get(_libraryKey);
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
            _downloads.add(download);
          } catch (_) {
            // Ignore a single corrupt entry and keep the remaining library.
          }
        }
      } catch (_) {
        SettingsStore.set(_libraryKey, '[]');
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
    final root = await AppPaths.voiceDir();
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
        tree: normalizedTree,
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
    item.selectedPaths.addAll(normalizedPaths);
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
    _requests[id]?.abort();
    item.status = VoiceDownloadStatus.queued;
    item.updatedAt = DateTime.now();
    unawaited(_persistAndNotify());
  }

  void toggleFile(VoiceDownload item, MediaNode node) {
    if (isDownloaded(item, node) || node.isDir) return;
    if (item.pausedPaths.remove(node.path)) {
      if (item.status == VoiceDownloadStatus.paused ||
          item.status == VoiceDownloadStatus.failed) {
        item.status = VoiceDownloadStatus.queued;
        item.error = null;
      }
      unawaited(_persistAndNotify());
      _pump();
      return;
    }
    item.pausedPaths.add(node.path);
    if (item.currentPath == node.path) {
      _cancelled.add(item.id);
      _requests[item.id]?.abort();
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
          _requests[item.id]?.abort();
        }
        if (item.status != VoiceDownloadStatus.completed) {
          item.status = VoiceDownloadStatus.paused;
        }
      }
    } else {
      for (final item in _downloads) {
        item.pausedPaths.clear();
        if (item.status != VoiceDownloadStatus.completed) {
          item.status = VoiceDownloadStatus.queued;
          item.error = null;
        }
      }
      _pump();
    }
    unawaited(_persistAndNotify());
  }

  Future<void> removeFileRecords(Map<String, Set<String>> selected) async {
    for (final entry in selected.entries) {
      final item = _find(entry.key);
      if (item == null) continue;
      if (item.currentPath != null && entry.value.contains(item.currentPath)) {
        _cancelled.add(item.id);
        _requests[item.id]?.abort();
      }
      final remaining = selectedFiles(item)
          .where((node) => !entry.value.contains(node.path))
          .map((node) => node.path)
          .toSet();
      if (remaining.isEmpty) {
        _cancelled.add(item.id);
        _requests[item.id]?.abort();
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
    for (final node in _filesAtPaths(item.tree, selectedPaths)) {
      if (!isDownloaded(item, node)) continue;
      final file = File(_localPath(item, node));
      try {
        await file.delete();
        deleted.add(node.path);
        item.fileSizes.remove(node.path);
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
      _cancelled.add(item.id);
      _requests[item.id]?.abort();
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
    }
    await _persistAndNotify();
  }

  void retry(String id) {
    final item = _find(id);
    if (item == null) return;
    item.status = VoiceDownloadStatus.queued;
    item.error = null;
    item.updatedAt = DateTime.now();
    unawaited(_persistAndNotify());
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
    return file.existsSync() && file.lengthSync() > 0 ? file.path : null;
  }

  String localPath(VoiceDownload item, MediaNode node) =>
      _localPath(item, node);

  bool isDownloaded(VoiceDownload item, MediaNode node) {
    if (node.isDir) return false;
    final file = File(_localPath(item, node));
    return file.existsSync() && file.lengthSync() > 0;
  }

  List<MediaNode> audioNodes(VoiceDownload item) {
    final result = <MediaNode>[];
    void walk(Iterable<MediaNode> nodes) {
      for (final node in nodes) {
        if (node.isDir) {
          walk(node.children);
        } else if (isAudioNode(node)) {
          result.add(node);
        }
      }
    }

    walk(item.tree);
    return result;
  }

  List<MediaNode> selectedAudioNodes(VoiceDownload item) =>
      audioNodes(item).where((node) => _isSelected(item, node.path)).toList();

  List<MediaNode> selectedFiles(VoiceDownload item) {
    final result = <MediaNode>[];
    void walk(Iterable<MediaNode> nodes) {
      for (final node in nodes) {
        if (node.isDir) {
          walk(node.children);
        } else if (_isSelected(item, node.path) &&
            (node.downloadUrl ?? node.url)?.isNotEmpty == true) {
          result.add(node);
        }
      }
    }

    walk(item.tree);
    return result;
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
    if (!_ready) return;
    while (_running.length < _maxConcurrentDownloads) {
      VoiceDownload? next;
      for (final item in _downloads) {
        if (item.status == VoiceDownloadStatus.queued &&
            !_running.containsKey(item.id)) {
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
      final files = selectedFiles(item);
      final runnable = files
          .where(
            (node) =>
                !isDownloaded(item, node) &&
                !item.pausedPaths.contains(node.path),
          )
          .toList();
      if (files.isEmpty) throw StateError('没有可下载的文件');
      if (runnable.isEmpty) {
        item.status = VoiceDownloadStatus.paused;
        await _persistAndNotify();
        return;
      }
      for (final node in runnable) {
        if (_cancelled.contains(item.id)) throw const _DownloadCancelled();
        if (isDownloaded(item, node)) continue;
        final url = node.downloadUrl ?? node.url;
        if (url == null || url.isEmpty) continue;
        item.currentPath = node.path;
        item.currentFileDownloaded = 0;
        item.currentFileTotal = item.fileSizes[node.path] ?? 0;
        await _persistAndNotify();
        await _downloadFile(item, node, url);
      }
      final pending = files.any((node) => !isDownloaded(item, node));
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
      item.status = selectedFiles(item).isEmpty && _hasLocalFiles(item)
          ? VoiceDownloadStatus.completed
          : item.pausedPaths.isEmpty
          ? VoiceDownloadStatus.queued
          : VoiceDownloadStatus.paused;
      item.currentPath = null;
      item.currentFileDownloaded = 0;
      item.currentFileTotal = 0;
      item.updatedAt = DateTime.now();
      await _persistAndNotify();
    } catch (e) {
      if (_cancelled.remove(item.id)) {
        item.status = VoiceDownloadStatus.queued;
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
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    var existing = partial.existsSync() ? await partial.length() : 0;
    final proxyUrl = apiStreamProxyUrl(url: url);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(minutes: 5);
    HttpClientResponse? response;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(proxyUrl));
      _requests[item.id] = request;
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      response = await request.close();
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
          existing > 0) {
        await partial.rename(target.path);
        return;
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          '下载失败 HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      final append =
          existing > 0 && response.statusCode == HttpStatus.partialContent;
      if (!append) {
        existing = 0;
        await partial.writeAsBytes(const [], flush: true);
      }
      final responseLength = response.contentLength;
      final total =
          _totalFromContentRange(response) ??
          (responseLength >= 0 ? existing + responseLength : 0);
      if (total > 0) {
        item.fileSizes[node.path] = total;
        item.totalBytes = item.fileSizes.values.fold(
          0,
          (sum, value) => sum + value,
        );
        item.currentFileTotal = total;
      }
      var received = existing;
      item.currentFileDownloaded = existing;
      var lastUpdate = DateTime.now();
      sink = partial.openWrite(mode: append ? FileMode.append : FileMode.write);
      await for (final chunk in response) {
        if (_cancelled.contains(item.id)) throw const _DownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        item.currentFileDownloaded = received;
        final now = DateTime.now();
        if (now.difference(lastUpdate) >= const Duration(milliseconds: 350)) {
          item.downloadedBytes = _completedBytes(item) + received;
          item.updatedAt = now;
          notifyListeners();
          await _persist();
          lastUpdate = now;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await partial.rename(target.path);
      item.downloadedBytes = _completedBytes(item);
      item.updatedAt = DateTime.now();
      await _persistAndNotify();
    } finally {
      await sink?.close();
      _requests.remove(item.id);
      client.close(force: true);
    }
  }

  int _completedBytes(VoiceDownload item) {
    var bytes = 0;
    for (final node in selectedFiles(item)) {
      if (isDownloaded(item, node)) {
        bytes += File(_localPath(item, node)).lengthSync();
      }
    }
    return bytes;
  }

  bool _hasLocalFiles(VoiceDownload item) {
    bool walk(Iterable<MediaNode> nodes) {
      for (final node in nodes) {
        if (node.isDir) {
          if (walk(node.children)) return true;
        } else if (isDownloaded(item, node)) {
          return true;
        }
      }
      return false;
    }

    return walk(item.tree);
  }

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

  bool _isSelected(VoiceDownload item, String path) {
    for (final selected in item.selectedPaths) {
      if (selected.isEmpty ||
          path == selected ||
          path.startsWith('$selected/')) {
        return true;
      }
    }
    return false;
  }

  List<MediaNode> _filesAtPaths(
    Iterable<MediaNode> nodes,
    Set<String> selectedPaths,
  ) {
    final result = <MediaNode>[];
    void walk(Iterable<MediaNode> current) {
      for (final node in current) {
        if (node.isDir) {
          walk(node.children);
        } else if (_pathIsSelected(selectedPaths, node.path)) {
          result.add(node);
        }
      }
    }

    walk(nodes);
    return result;
  }

  bool _pathIsSelected(Set<String> selectedPaths, String path) {
    for (final selected in selectedPaths) {
      if (selected.isEmpty ||
          path == selected ||
          path.startsWith('$selected/')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _persistAndNotify() async {
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_persisting) return;
    _persisting = true;
    try {
      SettingsStore.set(
        _libraryKey,
        jsonEncode(_downloads.map((item) => item.toJson()).toList()),
      );
    } finally {
      _persisting = false;
    }
  }
}

/// Removes the optional single display root returned by some media APIs.
/// Download storage already has a work directory, so retaining that root makes
/// a later API response with a different root name point at a different file.
List<MediaNode> normalizeDownloadTree(List<MediaNode> tree) {
  if (tree.length != 1 || !tree.first.isDir) return tree;
  final rootPath = tree.first.path;
  return tree.first.children
      .map((node) => _rebaseMediaNode(node, rootPath))
      .toList();
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
  final remaining = {for (final node in stored) node.path: node};
  final merged = <MediaNode>[];
  for (final node in refreshed) {
    final previous = remaining.remove(node.path);
    if (previous != null && previous.isDir && node.isDir) {
      merged.add(
        MediaNode(
          title: node.title,
          type: node.type,
          path: node.path,
          children: mergeDownloadTrees(previous.children, node.children),
          url: node.url,
          downloadUrl: node.downloadUrl,
          duration: node.duration,
        ),
      );
    } else {
      merged.add(node);
    }
  }
  merged.addAll(remaining.values);
  return merged;
}

MediaNode _rebaseMediaNode(MediaNode node, String rootPath) {
  final prefix = '$rootPath/';
  final path = node.path.startsWith(prefix)
      ? node.path.substring(prefix.length)
      : node.path;
  return MediaNode(
    title: node.title,
    type: node.type,
    path: path,
    children: node.children
        .map((child) => _rebaseMediaNode(child, rootPath))
        .toList(),
    url: node.url,
    downloadUrl: node.downloadUrl,
    duration: node.duration,
  );
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

int? _totalFromContentRange(HttpClientResponse response) {
  final value = response.headers.value(HttpHeaders.contentRangeHeader);
  if (value == null) return null;
  final match = RegExp(r'/([0-9]+)$').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}

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

Map<String, dynamic> _nodeToJson(MediaNode node) => {
  'title': node.title,
  'type': node.type,
  'path': node.path,
  'children': node.children.map(_nodeToJson).toList(),
  'url': node.url,
  'downloadUrl': node.downloadUrl,
  'duration': node.duration,
};

MediaNode _nodeFromJson(Map<String, dynamic> json) => MediaNode(
  title: json['title'] as String? ?? '',
  type: json['type'] as String? ?? 'file',
  path: json['path'] as String? ?? '',
  children: ((json['children'] as List?) ?? const [])
      .map((e) => _nodeFromJson(e as Map<String, dynamic>))
      .toList(),
  url: json['url'] as String?,
  downloadUrl: json['downloadUrl'] as String?,
  duration: (json['duration'] as num?)?.toInt() ?? 0,
);
