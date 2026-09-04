import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../data.dart';
import 'api_service.dart';
import 'app_paths.dart';
import 'settings_store.dart';
import '../src/rust/api/textcodec.dart';

String _normalizeRelative(String value) => value
    .replaceAll('\\', '/')
    .replaceAll(RegExp(r'^/+'), '')
    .replaceAll(RegExp(r'/+'), '/');

class LyricsLibraryRecord {
  final String workId;
  final String relativePath;
  final bool isAi;
  const LyricsLibraryRecord({
    required this.workId,
    required this.relativePath,
    this.isAi = false,
  });

  Map<String, dynamic> toJson() => {
    'workId': workId,
    'relativePath': relativePath,
    'isAi': isAi,
  };

  factory LyricsLibraryRecord.fromJson(Map<String, dynamic> json) =>
      LyricsLibraryRecord(
        workId: (json['workId'] as String? ?? '').toUpperCase(),
        relativePath: _normalizeRelative(json['relativePath'] as String? ?? ''),
        isAi: json['isAi'] == true,
      );
}

class LyricsLibraryFile {
  final String workId;
  final String relativePath;
  final String name;
  final String extension;
  final String absolutePath;
  final int score;
  const LyricsLibraryFile({
    required this.workId,
    required this.relativePath,
    required this.name,
    required this.extension,
    required this.absolutePath,
    this.score = 0,
  });
}

/// Compatibility name used by translation and player integrations.
typedef LyricsLibraryEntry = LyricsLibraryFile;

class LyricsTranslationInput {
  final String workId;
  final String relativePath;
  final String extension;
  final String sourceText;
  final List<LyricLine> lines;
  const LyricsTranslationInput({
    required this.workId,
    required this.relativePath,
    required this.extension,
    required this.sourceText,
    required this.lines,
  });
}

enum LyricsImportConflict { skip, overwrite, cancel }

class LyricsImportProgress {
  final String phase;
  final int current;
  final int total;
  final String? currentPath;

  const LyricsImportProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.currentPath,
  });

  double? get value => total > 0 ? (current / total).clamp(0.0, 1.0) : null;
}

class _ArchiveBudget {
  static const maxEntries = 100000;
  static const maxExpandedBytes = 2 * 1024 * 1024 * 1024;
  int entries = 0;
  int expandedBytes = 0;

  bool accept(ArchiveFile entry) {
    entries++;
    expandedBytes += entry.size;
    return entries <= maxEntries && expandedBytes <= maxExpandedBytes;
  }
}

/// 本地歌词库。文件系统负责内容，SettingsStore 只保存作品目录索引。
class LyricsLibraryService {
  LyricsLibraryService._();
  static final instance = LyricsLibraryService._();
  static const _key = 'lyrics_library_entries';
  static const supportedExtensions = {
    '.lrc',
    '.txt',
    '.srt',
    '.vtt',
    '.ass',
    '.ssa',
  };
  // 歌词库作品号只接受 RJ、VJ、BJ 前缀加数字。
  static final _workIdPattern = RegExp(
    r'^(?:RJ|VJ|BJ)\d+$',
    caseSensitive: false,
  );

  List<LyricsLibraryRecord> _records = [];
  bool _loaded = false;

  Future<String> get root async {
    // Windows 便携版的歌词库与 kikoeta.exe 同级，避免落到 kikoeta_data。
    final parent = Platform.isWindows
        ? File(Platform.resolvedExecutable).parent.path
        : await AppPaths.dataDir();
    final dir = '$parent${Platform.pathSeparator}lyrics';
    await Directory(dir).create(recursive: true);
    return dir;
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = SettingsStore.get(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      _records = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (e) => LyricsLibraryRecord.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.workId.isNotEmpty && e.relativePath.isNotEmpty)
          .toList();
    } catch (_) {
      _records = [];
    }
  }

  Future<void> _save() async {
    SettingsStore.set(
      _key,
      jsonEncode(_records.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<LyricsLibraryRecord>> records() async {
    await _load();
    return List.unmodifiable(_records);
  }

  static const largeImportBytes = 200 * 1024 * 1024;
  static const largeImportFileCount = 10000;

  Future<bool> isLargeImport(List<String> paths) async {
    var fileCount = 0;
    var totalBytes = 0;
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) {
        final size = await File(path).length();
        fileCount++;
        totalBytes += size;
        if (totalBytes >= largeImportBytes || fileCount >= largeImportFileCount)
          return true;
        continue;
      }
      if (type != FileSystemEntityType.directory) continue;
      await for (final entity in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        fileCount++;
        totalBytes += await entity.length();
        if (totalBytes >= largeImportBytes || fileCount >= largeImportFileCount)
          return true;
      }
    }
    return false;
  }

  Future<void> deleteWorks(Set<String> workIds) async {
    if (workIds.isEmpty) return;
    await _load();
    final base = await root;
    final removed = _records.where((r) => workIds.contains(r.workId)).toList();
    for (final record in removed) {
      final dir = Directory(_join(base, record.relativePath));
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
    _records.removeWhere((r) => workIds.contains(r.workId));
    await _save();
  }

  Future<List<LyricsLibraryRecord>> refresh({bool deep = false}) async {
    await _load();
    final base = Directory(await root);
    final discovered = <LyricsLibraryRecord>[];
    if (await base.exists()) {
      if (deep) await _pruneInvalidRootDirectories(base);
      await for (final entity in base.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! Directory) continue;
        final rel = _relative(base.path, entity.path);
        final parts = rel.split('/');
        final idPart = parts.where(_isWorkId).toList();
        if (idPart.isEmpty || idPart.last != parts.last) continue;
        final workId = idPart.last.toUpperCase();
        if (deep && !(await _containsSupportedFile(entity))) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
          continue;
        }
        discovered.add(
          LyricsLibraryRecord(
            workId: workId,
            relativePath: rel,
            isAi: _records.any(
              (r) => r.workId == workId && r.relativePath == rel && r.isAi,
            ),
          ),
        );
      }
    }
    _records = discovered;
    await _save();
    return records();
  }

  Future<void> _pruneInvalidRootDirectories(Directory base) async {
    await for (final entity in base.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (_isWorkId(name)) continue;
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // 单个旧目录无权限或正在使用时，继续处理其它目录。
      }
    }
  }

  Future<List<LyricsLibraryFile>> listFiles({required String workId}) async {
    await _load();
    final base = await root;
    final id = workId.toUpperCase();
    final out = <LyricsLibraryFile>[];
    for (final record in _records.where((r) => r.workId == id)) {
      final dir = Directory(_join(base, record.relativePath));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final ext = _extension(entity.path);
        if (!supportedExtensions.contains(ext)) continue;
        final relative = _relative(base, entity.path);
        final title = entity.path.split(Platform.pathSeparator).last;
        out.add(
          LyricsLibraryFile(
            workId: id,
            relativePath: relative,
            name: title,
            extension: ext,
            absolutePath: entity.path,
            score: 0,
          ),
        );
      }
    }
    return out;
  }

  Future<List<LyricsLibraryEntry>> listEntries({required String workId}) =>
      listFiles(workId: workId);

  Future<List<LyricsLibraryFile>> matchingFiles({
    required String workId,
    String? trackTitle,
    String? trackPath,
  }) async {
    final files = await listFiles(workId: workId);
    final candidates = files.map((f) => _candidate(f)).toList();
    candidates.sort((a, b) {
      final ma = _matchScore(a, trackTitle, trackPath);
      final mb = _matchScore(b, trackTitle, trackPath);
      return mb.compareTo(ma);
    });
    return candidates;
  }

  Future<List<LyricLine>> loadFile(LyricsLibraryFile file) async {
    try {
      final bytes = await File(file.absolutePath).readAsBytes();
      final decoded = apiDecodeText(bytes: bytes, encoding: '');
      return ApiService.parseLyrics(decoded.text);
    } catch (_) {
      return const [];
    }
  }

  Future<LyricsTranslationInput?> readForTranslation({
    required String workId,
    required String relativePath,
  }) async {
    final base = await root;
    final clean = _cleanRelative(relativePath);
    final file = File(_join(base, clean));
    await _load();
    final allowed = _records
        .where((r) => r.workId == workId.toUpperCase())
        .map((r) => _join(base, r.relativePath));
    if (!allowed.any((dir) => _isWithin(file.path, dir))) return null;
    if (!await file.exists()) return null;
    final sourceText = await file.readAsString();
    return LyricsTranslationInput(
      workId: workId.toUpperCase(),
      relativePath: clean,
      extension: _extension(clean),
      sourceText: sourceText,
      lines: ApiService.parseLyrics(sourceText),
    );
  }

  Future<LyricsLibraryRecord> saveTranslatedLyrics({
    required String workId,
    required String relativePath,
    required String content,
  }) async {
    final base = await root;
    final id = workId.toUpperCase();
    final clean = _cleanRelative(relativePath);
    final target = File(_join(base, clean));
    await _load();
    final workDirs = _records
        .where((r) => r.workId == id)
        .map((r) => _join(base, r.relativePath))
        .toList();
    if (workDirs.isEmpty) workDirs.add(_join(base, id));
    if (!workDirs.any((dir) => _isWithin(target.path, dir))) {
      throw ArgumentError('目标文件必须位于作品目录内');
    }
    if (!supportedExtensions.contains(_extension(clean))) {
      throw ArgumentError('不支持的歌词格式');
    }
    if (ApiService.parseLyrics(content).isEmpty) {
      throw ArgumentError('文件中没有有效时间轴');
    }
    await target.parent.create(recursive: true);
    await target.writeAsString(content, flush: true);
    final workDir = workDirs.firstWhere((dir) => _isWithin(target.path, dir));
    final relDir = _relative(base, workDir);
    final index = _records.indexWhere(
      (r) => r.workId == id && r.relativePath == relDir,
    );
    final record = LyricsLibraryRecord(
      workId: id,
      relativePath: relDir,
      isAi: true,
    );
    if (index >= 0) {
      _records[index] = record;
    } else {
      _records.add(record);
    }
    await _save();
    return record;
  }

  Future<void> importDirectory(
    String source, {
    LyricsImportConflict conflict = LyricsImportConflict.skip,
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    final sourceDir = Directory(source);
    if (!await sourceDir.exists()) return;
    final base = await root;
    final sourceName = sourceDir.path
        .split(Platform.pathSeparator)
        .where((e) => e.isNotEmpty)
        .last;
    if (_isWorkId(sourceName)) {
      await _copyTree(
        sourceDir,
        Directory(_join(base, _normalizedFolderName(sourceName))),
        conflict,
        onProgress: onProgress,
      );
    } else {
      await _copyWorkRoots(
        sourceDir,
        Directory(base),
        conflict,
        onProgress: onProgress,
      );
    }
    await refresh();
  }

  Future<void> _copyWorkRoots(
    Directory source,
    Directory target,
    LyricsImportConflict conflict, {
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    await for (final entity in source.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (_isWorkId(name)) {
        await _copyTree(
          entity,
          Directory(_join(target.path, _normalizedFolderName(name))),
          conflict,
          onProgress: onProgress,
        );
      } else {
        await _copyWorkRoots(entity, target, conflict, onProgress: onProgress);
      }
    }
  }

  /// 批量导入文件夹与 ZIP，供桌面端自定义选择器或未来平台 UI 使用。
  Future<void> importPaths(
    List<String> paths, {
    LyricsImportConflict conflict = LyricsImportConflict.skip,
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    for (final path in paths) {
      final ext = _extension(path);
      if (ext == '.zip') {
        await importZip(path, conflict: conflict, onProgress: onProgress);
      } else if (Directory(path).existsSync()) {
        await importDirectory(path, conflict: conflict, onProgress: onProgress);
      }
    }
    await refresh();
  }

  /// 返回即将写入且已存在的目标文件路径。仅用于导入前询问冲突策略，
  /// 不会修改文件系统。
  Future<List<String>> findConflicts(List<String> paths) async {
    final base = await root;
    final conflicts = <String>[];
    for (final source in paths) {
      final entity = FileSystemEntity.typeSync(source);
      if (entity == FileSystemEntityType.directory) {
        final sourceDir = Directory(source);
        await _collectDirectoryConflicts(sourceDir, base, conflicts);
      } else if (entity == FileSystemEntityType.file &&
          _extension(source) == '.zip') {
        try {
          final input = InputFileStream(source);
          try {
            final archive = ZipDecoder().decodeStream(input);
            await _collectArchiveConflicts(
              archive,
              base,
              conflicts,
              0,
              workIds: _archiveWorkIds(archive),
              budget: _ArchiveBudget(),
            );
          } finally {
            input.closeSync();
          }
        } catch (_) {
          // 实际导入时会再次报告无效压缩包，不把预检失败当成冲突。
        }
      }
    }
    return conflicts.toSet().toList();
  }

  Future<void> _collectDirectoryConflicts(
    Directory source,
    String base,
    List<String> conflicts,
  ) async {
    final name = source.path
        .split(Platform.pathSeparator)
        .where((e) => e.isNotEmpty)
        .last;
    if (_isWorkId(name)) {
      await for (final item in source.list(
        recursive: true,
        followLinks: false,
      )) {
        if (item is! File) continue;
        final relative = item.path
            .substring(source.path.length)
            .replaceAll('\\', '/')
            .replaceFirst(RegExp(r'^/'), '');
        final target = File(
          _join(base, '${_normalizedFolderName(name)}/$relative'),
        );
        if (await target.exists()) conflicts.add(_relative(base, target.path));
      }
      return;
    }
    await for (final child in source.list(followLinks: false)) {
      if (child is Directory) {
        await _collectDirectoryConflicts(child, base, conflicts);
      }
    }
  }

  Future<void> _collectArchiveConflicts(
    Archive archive,
    String base,
    List<String> conflicts,
    int depth, {
    Set<String> workIds = const {},
    _ArchiveBudget? budget,
  }) async {
    final activeBudget = budget ?? _ArchiveBudget();
    if (depth > 8) return;
    for (final entry in archive) {
      if (!activeBudget.accept(entry)) return;
      var clean = _safeArchivePath(entry.name);
      if (clean == null || clean.isEmpty || _ignored(clean)) continue;
      if (_extension(clean) == '.zip' && entry.isFile) {
        try {
          final nested = ZipDecoder().decodeBytes(entry.content as List<int>);
          final nestedId = _workIdFromName(_fileStem(clean));
          await _collectArchiveConflicts(
            nested,
            _join(base, _parent(clean)),
            conflicts,
            depth + 1,
            budget: activeBudget,
            workIds: {
              ..._archiveWorkIds(nested),
              if (nestedId != null) nestedId,
            },
          );
          entry.clear();
        } catch (_) {}
      } else if (entry.isFile) {
        final output = _archiveOutputPath(clean, workIds, isFile: true);
        if (output != null && await File(_join(base, output)).exists()) {
          conflicts.add(output);
        }
      }
    }
  }

  Future<void> importZip(
    String source, {
    LyricsImportConflict conflict = LyricsImportConflict.skip,
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    final base = await root;
    final input = InputFileStream(source);
    try {
      final archive = ZipDecoder().decodeStream(input);
      await _extractArchive(
        archive,
        base,
        conflict,
        0,
        workIds: _archiveWorkIds(archive),
        budget: _ArchiveBudget(),
        onProgress: onProgress,
      );
    } finally {
      input.closeSync();
    }
    await refresh();
  }

  Future<void> _extractArchive(
    Archive archive,
    String base,
    LyricsImportConflict conflict,
    int depth, {
    Set<String> workIds = const {},
    _ArchiveBudget? budget,
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    final activeBudget = budget ?? _ArchiveBudget();
    if (depth > 8) return;
    var index = 0;
    for (final entry in archive) {
      index++;
      onProgress?.call(
        LyricsImportProgress(
          phase: '正在解压',
          current: index,
          total: archive.length,
          currentPath: entry.name,
        ),
      );
      if (!activeBudget.accept(entry)) return;
      var clean = _safeArchivePath(entry.name);
      if (clean == null || clean.isEmpty || _ignored(clean)) continue;
      if (entry.isFile) {
        final nested = _extension(clean) == '.zip';
        if (nested) {
          try {
            final nestedArchive = ZipDecoder().decodeBytes(
              entry.content as List<int>,
            );
            await _extractArchive(
              nestedArchive,
              _join(base, _parent(clean)),
              conflict,
              depth + 1,
              budget: activeBudget,
              onProgress: onProgress,
              workIds: {
                ..._archiveWorkIds(nestedArchive),
                if (_workIdFromName(_fileStem(clean)) != null)
                  _workIdFromName(_fileStem(clean))!,
              },
            );
          } catch (_) {}
          continue;
        }
        final output = _archiveOutputPath(clean, workIds, isFile: true);
        if (output == null) continue;
        final target = File(_join(base, output));
        if (await target.exists() && conflict == LyricsImportConflict.skip)
          continue;
        if (await target.exists() && conflict == LyricsImportConflict.cancel)
          return;
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.content as List<int>, flush: true);
        entry.clear();
      } else {
        final output = _archiveOutputPath(clean, workIds, isFile: false);
        if (output != null) {
          await Directory(_join(base, output)).create(recursive: true);
        }
      }
    }
  }

  Future<void> _copyTree(
    Directory source,
    Directory target,
    LyricsImportConflict conflict, {
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      final name = _normalizedFolderName(
        entity.path.split(Platform.pathSeparator).last,
      );
      final dst = FileSystemEntity.isDirectorySync(entity.path)
          ? Directory(_join(target.path, name))
          : File(_join(target.path, name));
      if (entity is Directory) {
        await _copyTree(
          entity,
          dst as Directory,
          conflict,
          onProgress: onProgress,
        );
      } else if (entity is File) {
        if (await dst.exists() && conflict == LyricsImportConflict.skip)
          continue;
        if (await dst.exists() && conflict == LyricsImportConflict.cancel)
          return;
        await dst.parent.create(recursive: true);
        await entity.copy(dst.path);
        onProgress?.call(
          LyricsImportProgress(
            phase: '正在复制',
            current: 0,
            total: 0,
            currentPath: entity.path,
          ),
        );
      }
    }
  }

  Future<bool> _containsSupportedFile(Directory dir) async {
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File && supportedExtensions.contains(_extension(e.path)))
        return true;
    }
    return false;
  }

  LyricsLibraryFile _candidate(LyricsLibraryFile f) => f;
  int _matchScore(LyricsLibraryFile file, String? title, String? path) {
    var score = _formatPriority(file.name) * 10;
    if (title != null &&
        ApiService.lyricMatchKey(file.name) == ApiService.lyricMatchKey(title))
      score += 1000;
    if (path != null &&
        _parent(file.relativePath).toLowerCase() == _parent(path).toLowerCase())
      score += 100;
    return score;
  }

  static int _formatPriority(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.lrc')) return 5;
    if (lower.endsWith('.srt')) return 4;
    if (lower.endsWith('.vtt')) return 3;
    if (lower.endsWith('.ass') || lower.endsWith('.ssa')) return 2;
    if (lower.endsWith('.txt')) return 1;
    return 0;
  }

  static String _cleanRelative(String value) => _normalizeRelative(value);

  static String _fileStem(String path) {
    final name = path.split('/').last;
    return name.replaceFirst(RegExp(r'\.[^.]*$'), '');
  }

  static String? _workIdFromName(String name) {
    final match = RegExp(
      r'^([A-Za-z]+\d+)(?:\s+.*|[-_].*)?$',
    ).firstMatch(name.trim());
    if (match == null) return null;
    final candidate = match.group(1)!.toUpperCase();
    return _isWorkId(candidate) ? candidate : null;
  }

  static bool _isWorkId(String value) {
    final normalized = value.trim().toUpperCase();
    return _workIdPattern.hasMatch(normalized);
  }

  static String _normalizedFolderName(String name) {
    return _workIdFromName(name) ?? name;
  }

  static String? _archiveOutputPath(
    String clean,
    Set<String> workIds, {
    required bool isFile,
  }) {
    final parts = clean.split('/');
    final index = parts.indexWhere(_isWorkId);
    if (index >= 0) {
      return [
        _normalizedFolderName(parts[index]),
        ...parts.skip(index + 1),
      ].join('/');
    }
    if (isFile && _isLyricFile(clean) && workIds.length == 1) {
      return '${workIds.first}/$clean';
    }
    return null;
  }

  static bool _isLyricFile(String path) =>
      supportedExtensions.contains(_extension(path));

  static Set<String> _archiveWorkIds(Archive archive) {
    final ids = <String>{};
    for (final entry in archive) {
      final clean = _safeArchivePath(entry.name);
      if (clean == null || clean.isEmpty || _ignored(clean)) continue;
      for (final part in clean.split('/')) {
        if (_isWorkId(part)) {
          ids.add(_normalizedFolderName(part));
          break;
        }
      }
      if (entry.isFile && _extension(clean) == '.zip') {
        final fileId = _workIdFromName(_fileStem(clean));
        if (fileId != null) ids.add(fileId);
      }
      if (entry.isFile && _extension(clean) == '.zip') {
        try {
          ids.addAll(
            _archiveWorkIds(
              ZipDecoder().decodeBytes(entry.content as List<int>),
            ),
          );
        } catch (_) {}
      }
    }
    return ids;
  }

  static String _join(String a, String b) =>
      '$a${Platform.pathSeparator}${b.replaceAll('/', Platform.pathSeparator)}';
  static String _relative(String base, String path) => path
      .substring(base.length)
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/'), '');
  static String _extension(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i).toLowerCase();
  }

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  static bool _ignored(String path) => path
      .split('/')
      .any((p) => p == '__MACOSX' || p == '.DS_Store' || p == 'Thumbs.db');
  static String? _safeArchivePath(String raw) {
    final p = _cleanRelative(raw);
    if (p.isEmpty || p.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(p))
      return null;
    final parts = p.split('/');
    if (parts.any((part) => part == '..' || part.isEmpty)) return null;
    return parts.map(_normalizedFolderName).join('/');
  }

  static bool _isWithin(String path, String parent) {
    final a = File(path).absolute.path.toLowerCase();
    final b = Directory(parent).absolute.path.toLowerCase();
    return a == b || a.startsWith('$b${Platform.pathSeparator}');
  }
}
