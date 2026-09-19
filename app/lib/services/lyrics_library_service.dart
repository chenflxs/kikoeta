import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

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

enum LyricsLibraryStatus { none, local, ai }

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
  // 大型前置包会包含一万多个子 ZIP，每个子包又有多条歌词/目录记录。
  // 例如 16347 部的实包共 142400 条目，原来的 10 万上限会静默截断。
  // 内容展开量仍受 2 GiB 限制，避免提高条目数后放宽压缩炸弹防护。
  static const maxEntries = 250000;
  static const maxExpandedBytes = 2 * 1024 * 1024 * 1024;
  int entries = 0;
  int expandedBytes = 0;

  bool accept(ArchiveFile entry) {
    entries++;
    expandedBytes += entry.size;
    return entries <= maxEntries && expandedBytes <= maxExpandedBytes;
  }
}

/// ZIP 中央目录里保存的原始文件名。ZIP 规范只有在 bit 11 置位时才保证
/// 文件名为 UTF-8；不少旧的日系/中文资源包会直接写入 GBK 或 Shift_JIS。
class _ZipEntryName {
  final List<int> bytes;
  final bool isUtf8;

  const _ZipEntryName(this.bytes, this.isUtf8);
}

class _ZipCentralDirectory {
  final int offset;
  final int size;

  const _ZipCentralDirectory(this.offset, this.size);
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
  // Android/Linux 的单个文件名最多 255 字节。使用更保守的长度，给
  // 其它文件系统和后续生成的路径保留空间。
  static const _maxPathPartBytes = 120;

  List<LyricsLibraryRecord> _records = [];
  bool _loaded = false;
  final ValueNotifier<int> _revision = ValueNotifier(0);

  ValueListenable<int> get revision => _revision;

  void _notifyChanged() => _revision.value++;

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
        if (!_isLyricFile(entity.path)) continue;
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
    _notifyChanged();
  }

  Future<List<LyricsLibraryRecord>> refresh({bool deep = false}) async {
    await _load();
    final base = Directory(await root);
    final discovered = <LyricsLibraryRecord>[];
    final discoveredPaths = <String>{};
    final existingAiPaths = {
      for (final record in _records)
        '${record.workId}\u0000${record.relativePath}': record.isAi,
    };
    if (await base.exists()) {
      if (deep) {
        await _pruneInvalidRootDirectories(base);
        await _repairLegacyZipEntryNames(base);
      }

      // 正常刷新只检查歌词库的顶层作品目录。导入流程会把作品目录放在
      // 这里，因此无需为发现变化而递归读取每个歌词文件。保留已建立的
      // 嵌套目录索引，以兼容旧版本留下的目录结构；长按的深度刷新仍会
      // 完整扫描并清理无效目录。
      if (!deep) {
        for (final record in _records) {
          final dir = Directory(_join(base.path, record.relativePath));
          if (!await dir.exists()) continue;
          discovered.add(record);
          discoveredPaths.add(record.relativePath);
        }
      }
      await for (final entity in base.list(
        recursive: deep,
        followLinks: false,
      )) {
        if (entity is! Directory) continue;
        final rel = _relative(base.path, entity.path);
        if (!discoveredPaths.add(rel)) continue;
        final parts = rel.split('/');
        final workId = _workIdFromName(parts.last);
        if (workId == null) continue;
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
            isAi: existingAiPaths['$workId\u0000$rel'] ?? false,
          ),
        );
      }
    }
    _records = discovered;
    await _save();
    _notifyChanged();
    return records();
  }

  Future<void> _pruneInvalidRootDirectories(Directory base) async {
    await for (final entity in base.list(followLinks: false)) {
      // 歌词库根目录只允许作品目录。旧版处理大型前置包时曾把内嵌 ZIP
      // 直接写成无扩展名文件；深度刷新时一并清理这些无效残留。
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {
          // 正在被外部程序占用时保留，下一次深度刷新再处理。
        }
        continue;
      }
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (_workIdFromName(name) != null) continue;
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // 单个旧目录无权限或正在使用时，继续处理其它目录。
      }
    }
  }

  /// 兼容修复旧版本已导入的乱码名称。旧 archive 解码器会把 ZIP 原始
  /// 字节逐个映射为 Unicode；只对这种“全部落在单字节区间且含多个高位
  /// 字节”的名称尝试恢复，并且仅在结果含中日韩文字时才改名，避免碰到
  /// 用户原本的西文文件名。该操作只在用户主动选择深度刷新时执行。
  Future<void> _repairLegacyZipEntryNames(Directory base) async {
    final entities = <FileSystemEntity>[];
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is File || entity is Directory) entities.add(entity);
    }
    final namesByWorkRoot = <String, List<_ZipEntryName>>{};
    for (final entity in entities) {
      final rel = _relative(base.path, entity.path);
      final workRoot = rel.split('/').first;
      final bytes = entity.path.split(Platform.pathSeparator).last.codeUnits;
      // 已经正确的中日韩名称包含大于 255 的 Unicode 码位，不能混入
      // “原始 ZIP 字节”样本，否则会污染旧乱码的编码判定。
      if (bytes.any((byte) => byte > 0xff) ||
          bytes.where((byte) => byte >= 0x80).length < 2) {
        continue;
      }
      (namesByWorkRoot[workRoot] ??= []).add(
        _ZipEntryName(bytes, false),
      );
    }
    final encodings = {
      for (final entry in namesByWorkRoot.entries)
        entry.key: _detectZipEntryEncoding(entry.value),
    };
    // 先处理最深层节点，随后改父目录名，不会让尚未处理的子路径失效。
    entities.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final entity in entities) {
      final original = entity.path.split(Platform.pathSeparator).last;
      final workRoot = _relative(base.path, entity.path).split('/').first;
      final repaired = _decodeLegacyZipNameWithEncoding(
        original,
        encoding: encodings[workRoot],
      );
      if (repaired == null || repaired == original) continue;
      final target = _join(entity.parent.path, repaired);
      if (await File(target).exists() || await Directory(target).exists()) {
        continue;
      }
      try {
        await entity.rename(target);
      } catch (_) {
        // 可能遇到被播放器占用的歌词；跳过后继续处理其它文件。
      }
    }
  }

  Future<List<LyricsLibraryFile>> listFiles({required String workId}) async {
    await _load();
    final base = await root;
    final id = workId.toUpperCase();
    return _listFiles(base, id);
  }

  /// 批量统计首页卡片的文件数。共享一次索引和根目录解析，避免首批卡片
  /// 同时重复创建歌词库目录并分别读取相同的作品目录记录。
  Future<Map<String, int>> countFilesForWorks(Iterable<String> workIds) async {
    await _load();
    final base = await root;
    final ids = workIds.map((id) => id.toUpperCase()).toSet();
    final result = <String, int>{};
    for (final id in ids) {
      result[id] = await _countFiles(base, id);
    }
    return result;
  }

  Future<List<LyricsLibraryFile>> _listFiles(String base, String id) async {
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

  Future<int> _countFiles(String base, String id) async {
    var count = 0;
    for (final record in _records.where((r) => r.workId == id)) {
      final dir = Directory(_join(base, record.relativePath));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            supportedExtensions.contains(_extension(entity.path))) {
          count++;
        }
      }
    }
    return count;
  }

  Future<List<LyricsLibraryEntry>> listEntries({required String workId}) =>
      listFiles(workId: workId);

  /// 返回作品在歌词库中的来源类型。索引只在导入/删除时更新，因此无需在
  /// 首页卡片构建时扫描每个作品目录。
  Future<LyricsLibraryStatus> statusForWork(String workId) async {
    await _load();
    final id = workId.toUpperCase();
    final records = _records.where((record) => record.workId == id);
    if (records.any((record) => record.isAi)) return LyricsLibraryStatus.ai;
    return records.isEmpty
        ? LyricsLibraryStatus.none
        : LyricsLibraryStatus.local;
  }

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
    _notifyChanged();
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
    final sourceWorkId = _workIdFromName(sourceName);
    if (sourceWorkId != null) {
      await _copyTree(
        sourceDir,
        Directory(_join(base, sourceWorkId)),
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
      final workId = _workIdFromName(name);
      if (workId != null) {
        await _copyTree(
          entity,
          Directory(_join(target.path, workId)),
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
    Map<String, String> sourceNames = const {},
    LyricsImportConflict conflict = LyricsImportConflict.skip,
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    for (final path in paths) {
      final ext = _extension(path);
      if (ext == '.zip') {
        await importZip(
          path,
          sourceName: sourceNames[path],
          conflict: conflict,
          onProgress: onProgress,
        );
      } else if (Directory(path).existsSync()) {
        await importDirectory(path, conflict: conflict, onProgress: onProgress);
      }
    }
    await refresh();
  }

  /// 返回即将写入且已存在的目标文件路径。仅用于导入前询问冲突策略，
  /// 不会修改文件系统。
  Future<List<String>> findConflicts(
    List<String> paths, {
    Map<String, String> sourceNames = const {},
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
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
            await _repairZipEntryNamesFromFile(archive, source);
            final workIds = _archiveWorkIdsWithFallback(
              archive,
              sourceNames[source] ?? source,
            );
            await _collectArchiveConflicts(
              archive,
              base,
              conflicts,
              0,
              workIds: workIds,
              budget: _ArchiveBudget(),
              onProgress: onProgress,
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
    final workId = _workIdFromName(name);
    if (workId != null) {
      await for (final item in source.list(
        recursive: true,
        followLinks: false,
      )) {
        if (item is! File) continue;
        if (!_isLyricFile(item.path)) continue;
        final relative = item.path
            .substring(source.path.length)
            .replaceAll('\\', '/')
            .replaceFirst(RegExp(r'^/'), '');
        final target = File(_join(base, '$workId/$relative'));
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
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    final activeBudget = budget ?? _ArchiveBudget();
    if (depth > 8) return;
    var index = 0;
    for (final entry in archive) {
      index++;
      // 只展示最外层条目进度。内嵌作品包很小，若用它们的条目数重置
      // 进度条，会让数千包导入看起来像在反复倒退。
      if (depth == 0) {
        onProgress?.call(
          LyricsImportProgress(
            phase: '正在检查文件冲突',
            current: index,
            total: archive.length,
            currentPath: entry.name,
          ),
        );
      }
      if (!activeBudget.accept(entry)) return;
      var clean = _safeArchivePath(entry.name);
      if (clean == null || clean.isEmpty || _ignored(clean)) continue;
      if (_extension(clean) == '.zip' && entry.isFile) {
        try {
          final nested = _decodeZipBytes(entry.content as List<int>);
          final nestedWorkIds = _nestedArchiveWorkIds(nested, clean, workIds);
          await _collectArchiveConflicts(
            nested,
            // 前置包常用一个无作品号的总目录包住数千个 RJ/BJ 子 ZIP。
            // 子包的文件名或内容已能确定作品号，不能把总目录带入歌词库。
            base,
            conflicts,
            depth + 1,
            budget: activeBudget,
            workIds: nestedWorkIds,
            onProgress: onProgress,
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
    String? sourceName,
    LyricsImportConflict conflict = LyricsImportConflict.skip,
    void Function(LyricsImportProgress progress)? onProgress,
  }) async {
    final base = await root;
    final input = InputFileStream(source);
    try {
      final archive = ZipDecoder().decodeStream(input);
      await _repairZipEntryNamesFromFile(archive, source);
      final workIds = _archiveWorkIdsWithFallback(
        archive,
        sourceName ?? source,
      );
      await _extractArchive(
        archive,
        base,
        conflict,
        0,
        workIds: workIds,
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
      if (depth == 0) {
        onProgress?.call(
          LyricsImportProgress(
            phase: '正在解压',
            current: index,
            total: archive.length,
            currentPath: entry.name,
          ),
        );
      }
      if (!activeBudget.accept(entry)) return;
      var clean = _safeArchivePath(entry.name);
      if (clean == null || clean.isEmpty || _ignored(clean)) continue;
      if (entry.isFile) {
        final nested = _extension(clean) == '.zip';
        if (nested) {
          try {
            final nestedArchive = _decodeZipBytes(entry.content as List<int>);
            final nestedWorkIds = _nestedArchiveWorkIds(
              nestedArchive,
              clean,
              workIds,
            );
            await _extractArchive(
              nestedArchive,
              // 与冲突检测一致，内嵌作品包直接写入歌词库根目录，由
              // _archiveOutputPath 统一添加 RJ/VJ/BJ 作品目录。
              base,
              conflict,
              depth + 1,
              budget: activeBudget,
              onProgress: onProgress,
              workIds: nestedWorkIds,
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
      final name = _shortenPathPart(
        _normalizedFolderName(entity.path.split(Platform.pathSeparator).last),
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
        if (!_isLyricFile(entity.path)) continue;
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
    if (title != null) score += ApiService.lyricMatchScore(title, file.name);
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
      r'(?:^|[^A-Za-z0-9])((?:RJ|VJ|BJ)\d+)(?!\d)',
      caseSensitive: false,
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

  /// 将超长的目录或文件名缩短为“前缀-哈希.扩展名”。
  ///
  /// ZIP 中的歌词标题可能包含完整的演出说明，单个名称会超过 Android
  /// 文件系统的 255 字节限制。哈希避免截断后同名前缀的文件相互覆盖，
  /// 并保留常见歌词扩展名，使后续格式识别保持不变。
  static String _shortenPathPart(String value) {
    final bytes = utf8.encode(value);
    if (bytes.length <= _maxPathPartBytes) return value;

    final dot = value.lastIndexOf('.');
    var extension = dot > 0 ? value.substring(dot) : '';
    // 目录名里的点，或异常长的“扩展名”，不值得占用缩短后的名称空间。
    if (utf8.encode(extension).length > 24) extension = '';

    final hash = _pathHash(value);
    final suffix = '-$hash$extension';
    final prefixBudget = _maxPathPartBytes - utf8.encode(suffix).length;
    final prefix = StringBuffer();
    var usedBytes = 0;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final charBytes = utf8.encode(char).length;
      if (usedBytes + charBytes > prefixBudget) break;
      prefix.write(char);
      usedBytes += charBytes;
    }
    return '${prefix.toString()}$suffix';
  }

  static String _pathHash(String value) {
    // FNV-1a 的 32 位实现足以区分导入包内同前缀的超长文件名，且无需
    // 额外引入加密依赖。
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// archive 包目前会把未标记为 UTF-8 的 ZIP 文件名按单字节字符直接
  /// 转成 String。这里从中央目录取回原始字节，交给已有的编码探测器
  /// 解码，再将修复后的名称写回条目。文件内容仍完全由 archive 包解压。
  static Future<void> _repairZipEntryNamesFromFile(
    Archive archive,
    String source,
  ) async {
    final names = await _readZipEntryNamesFromFile(source);
    _repairZipEntryNames(archive, names);
  }

  static Archive _decodeZipBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    _repairZipEntryNames(archive, _readZipEntryNames(bytes));
    return archive;
  }

  static void _repairZipEntryNames(
    Archive archive,
    List<_ZipEntryName> rawNames,
  ) {
    if (rawNames.isEmpty || archive.isEmpty) return;

    // 单个短曲名常被编码探测器误判（例如 Shift_JIS 被猜成 GBK）。同一
    // ZIP 通常使用统一代码页，因此先以整包文件名样本做一次判定。
    final archiveEncoding = _detectZipEntryEncoding(rawNames);

    // archive 包会将无效 UTF-8 回退成 String.fromCharCodes；以同样规则
    // 建索引，避免目录中混有 UTF-8 与本地编码条目时错配名称。
    final pending = <String, List<_ZipEntryName>>{};
    for (final raw in rawNames) {
      (pending[_archivePackageName(raw.bytes)] ??= []).add(raw);
    }
    for (var index = 0; index < archive.length; index++) {
      final entry = archive[index];
      final candidates = pending[entry.name];
      if (candidates == null || candidates.isEmpty) continue;
      final raw = candidates.removeAt(0);
      if (raw.isUtf8) continue;
      try {
        final name = apiDecodeText(
          bytes: raw.bytes,
          encoding: archiveEncoding ?? '',
        ).text;
        if (name.isEmpty || name == entry.name || name.contains('\u0000')) {
          continue;
        }
        // 后续只会顺序遍历 Archive；直接改名可避免 archive 对同名条目的
        // 去重索引干扰原始中央目录与条目的对应关系。
        entry.name = name;
      } catch (_) {
        // 个别异常编码保留 archive 的兼容性回退结果，不能中断整个导入。
      }
    }
  }

  static String _archivePackageName(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  static String? _decodeLegacyZipNameWithEncoding(
    String value, {
    String? encoding,
  }) {
    final bytes = value.codeUnits;
    // String.fromCharCodes 的遗留乱码可无损还原为字节；合法的中日韩
    // 文件名不满足这个条件，因而不会被误处理。
    if (bytes.any((byte) => byte > 0xff) ||
        bytes.where((byte) => byte >= 0x80).length < 2) {
      return null;
    }
    try {
      final decoded = apiDecodeText(
        bytes: bytes,
        encoding: encoding ?? '',
      ).text;
      if (!_containsEastAsianText(decoded)) return null;
      return _shortenPathPart(decoded);
    } catch (_) {
      return null;
    }
  }

  static bool _containsEastAsianText(String value) => RegExp(
    r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',
  ).hasMatch(value);

  static String? _detectZipEntryEncoding(List<_ZipEntryName> rawNames) {
    const maxSampleBytes = 256 * 1024;
    final sample = <int>[];
    for (final entry in rawNames) {
      if (entry.isUtf8 || !entry.bytes.any((byte) => byte >= 0x80)) continue;
      final remaining = maxSampleBytes - sample.length;
      if (remaining <= 0) break;
      sample.addAll(entry.bytes.take(remaining));
      if (sample.length < maxSampleBytes) sample.add(0x0a);
    }
    if (sample.isEmpty) return null;
    try {
      final autoEncoding = apiDecodeText(bytes: sample, encoding: '').encoding;
      // GB18030 可以编码日文，而错误地按 Big5 解码时也往往不会产生替换
      // 字符，单靠通用探测器仍可能误判。对常见 ZIP 代码页进行一次比较：
      // 若某个候选明显还原出更多假名，就优先采用它。
      const candidates = ['gb18030', 'shift_jis', 'euc-jp', 'big5'];
      String? japaneseEncoding;
      var bestJapaneseScore = 0;
      for (final candidate in candidates) {
        final text = apiDecodeText(bytes: sample, encoding: candidate).text;
        final score = _japaneseTextScore(text);
        if (score > bestJapaneseScore) {
          bestJapaneseScore = score;
          japaneseEncoding = candidate;
        }
      }
      if (japaneseEncoding != null && bestJapaneseScore >= 20) {
        return japaneseEncoding;
      }
      // 未标记 UTF-8 的条目若真的可按 UTF-8 读取，archive 本来就已经
      // 正确处理；其余情况回退逐条探测，避免以 UTF-8 强制替换字符。
      return autoEncoding.toUpperCase() == 'UTF-8' ? null : autoEncoding;
    } catch (_) {
      return null;
    }
  }

  static int _japaneseTextScore(String value) {
    var score = 0;
    for (final rune in value.runes) {
      // 不计入日文标点（例如「・」）。错误的 EUC-JP 解码会产生大量
      // 该字符，若纳入评分反而会压过正确的 GB18030 结果。
      if ((rune >= 0x3041 && rune <= 0x3096) ||
          (rune >= 0x30a1 && rune <= 0x30fa)) {
        score += 4;
      } else if (rune == 0xfffd) {
        score -= 100;
      }
    }
    return score;
  }

  static Future<List<_ZipEntryName>> _readZipEntryNamesFromFile(
    String source,
  ) async {
    RandomAccessFile? file;
    try {
      file = await File(source).open();
      final length = await file.length();
      // EOCD 之后最多只有 65535 字节注释和 22 字节固定头。
      final tailLength = math.min(length, 0xffff + 22).toInt();
      await file.setPosition(length - tailLength);
      final tail = await file.read(tailLength);
      final directory = _zipCentralDirectory(tail);
      if (directory == null || directory.offset + directory.size > length) {
        return const [];
      }
      await file.setPosition(directory.offset);
      final data = await file.read(directory.size);
      if (data.length != directory.size) return const [];
      return _parseZipEntryNames(data);
    } catch (_) {
      return const [];
    } finally {
      await file?.close();
    }
  }

  static List<_ZipEntryName> _readZipEntryNames(List<int> bytes) {
    final directory = _zipCentralDirectory(bytes);
    if (directory == null || directory.offset + directory.size > bytes.length) {
      return const [];
    }
    return _parseZipEntryNames(
      bytes.sublist(directory.offset, directory.offset + directory.size),
    );
  }

  static _ZipCentralDirectory? _zipCentralDirectory(List<int> bytes) {
    // 从末尾倒找 EOCD，避免注释中恰好出现签名时误判。
    final first = math.max(0, bytes.length - 0xffff - 22);
    for (var index = bytes.length - 22; index >= first; index--) {
      if (_readUint32(bytes, index) != 0x06054b50) continue;
      final commentLength = _readUint16(bytes, index + 20);
      if (index + 22 + commentLength > bytes.length) continue;
      return _ZipCentralDirectory(
        _readUint32(bytes, index + 16),
        _readUint32(bytes, index + 12),
      );
    }
    return null;
  }

  static List<_ZipEntryName> _parseZipEntryNames(List<int> bytes) {
    final names = <_ZipEntryName>[];
    var offset = 0;
    while (offset + 46 <= bytes.length) {
      if (_readUint32(bytes, offset) != 0x02014b50) break;
      final flags = _readUint16(bytes, offset + 8);
      final filenameLength = _readUint16(bytes, offset + 28);
      final extraLength = _readUint16(bytes, offset + 30);
      final commentLength = _readUint16(bytes, offset + 32);
      final end = offset + 46 + filenameLength + extraLength + commentLength;
      if (end > bytes.length) return const [];
      names.add(
        _ZipEntryName(
          List<int>.from(bytes.sublist(offset + 46, offset + 46 + filenameLength)),
          (flags & 0x800) != 0,
        ),
      );
      offset = end;
    }
    return names;
  }

  static int _readUint16(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _readUint32(List<int> bytes, int offset) =>
      _readUint16(bytes, offset) | (_readUint16(bytes, offset + 2) << 16);

  static String? _archiveOutputPath(
    String clean,
    Set<String> workIds, {
    required bool isFile,
  }) {
    if (isFile && !_isLyricFile(clean)) return null;
    final parts = clean.split('/');
    final index = parts.indexWhere((part) => _workIdFromName(part) != null);
    if (index >= 0) {
      final workId = _workIdFromName(parts[index])!;
      // `RJ12345.lrc` 是常见的单文件歌词包结构。它携带作品号，但它
      // 本身仍是文件而不是作品目录；保留完整文件名并创建作品目录。
      if (isFile && index == parts.length - 1) {
        return '$workId/${parts.last}';
      }
      return [
        workId,
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
        final workId = _workIdFromName(part);
        if (workId != null) {
          ids.add(workId);
          break;
        }
      }
      if (entry.isFile && _extension(clean) == '.zip') {
        final fileId = _workIdFromName(_fileStem(clean));
        if (fileId != null) ids.add(fileId);
      }
      // 不在这里递归读取内嵌 ZIP。大型前置包可能包含数千个作品包，
      // 递归预扫描会阻塞 UI，使进度弹窗只能闪现。每个内嵌包在实际
      // 解压时会按其自身文件名（如 RJ01000571.zip）取得作品号。
    }
    return ids;
  }

  /// 若包内路径没有作品号，则使用 ZIP 文件名（例如 VJ012072.zip）。
  /// 许多歌词包只有曲目目录和文件名，旧逻辑会因没有输出目录而静默跳过。
  static Set<String> _archiveWorkIdsWithFallback(
    Archive archive,
    String archivePath,
  ) {
    final ids = _archiveWorkIds(archive);
    if (ids.isNotEmpty) return ids;
    final workId = _workIdFromName(_fileStem(archivePath));
    return workId == null ? ids : {workId};
  }

  /// 内嵌 ZIP 未标注作品号时，沿用外层单一作品号，避免其歌词被跳过。
  static Set<String> _nestedArchiveWorkIds(
    Archive archive,
    String archivePath,
    Set<String> inheritedWorkIds,
  ) {
    final ids = _archiveWorkIdsWithFallback(archive, archivePath);
    return ids.isEmpty ? inheritedWorkIds : ids;
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
    return parts
        .map(_normalizedArchivePathPart)
        .map(_shortenPathPart)
        .join('/');
  }

  /// 目录名可以把“RJ12345 作品名”折叠成作品号，但 ZIP 文件名的扩展名
  /// 是类型判断的一部分。此前对 `RJ12345.zip` 套用目录规则会丢掉
  /// `.zip`，导致内嵌作品包被当作普通、不可导入文件而跳过。
  static String _normalizedArchivePathPart(String name) =>
      _extension(name).isEmpty ? _normalizedFolderName(name) : name;

  static bool _isWithin(String path, String parent) {
    final a = File(path).absolute.path.toLowerCase();
    final b = Directory(parent).absolute.path.toLowerCase();
    return a == b || a.startsWith('$b${Platform.pathSeparator}');
  }
}
