import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/lyrics_folder_import.dart';
import '../services/lyrics_library_service.dart';
import '../smooth_scroll.dart';
import '../subpage_swipe.dart';
import '../theme.dart';
import '../widgets.dart';
import '../l10n/strings.dart';

class LyricsLibraryPage extends StatefulWidget {
  const LyricsLibraryPage({super.key, this.service});

  final LyricsLibraryService? service;

  @override
  State<LyricsLibraryPage> createState() => _LyricsLibraryPageState();
}

class _LyricsLibraryPageState extends State<LyricsLibraryPage> {
  static const _batchSize = 50;
  late final _service = widget.service ?? LyricsLibraryService.instance;
  List<String> _workIds = [];
  List<String> _filteredWorkIds = [];
  Timer? _searchTimer;
  Map<String, int> _directoryCounts = {};
  Set<String> _aiWorkIds = {};
  Set<String> _translatedWorkIds = {};
  Set<String> _onlineWorkIds = {};
  Map<String, List<LyricsLibraryFile>> _files = {};
  String _source = 'local';
  bool _aiOnly = false;
  bool _loading = false;
  bool _importing = false;
  bool _deleting = false;
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _searching = false;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Map<String, int> _fileCounts = {};
  final Set<String> _countFailures = {};
  int _countLoadToken = 0;
  int _fileListRequest = 0;
  int _visibleCount = _batchSize;
  bool _loadingMore = false;
  int _refreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialRecords();
  }

  @override
  void dispose() {
    ++_refreshGeneration;
    ++_countLoadToken;
    _searchTimer?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSelection(String workId) {
    setState(() {
      if (!_selected.add(workId)) _selected.remove(workId);
    });
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  void _selectAll(List<String> ids) {
    setState(() {
      if (_selected.length == ids.length && ids.every(_selected.contains)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    if (_selected.isEmpty || _deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _source == 'remote'
              ? l10n.lyricsLibraryPageOkText3
              : l10n.lyricsLibraryPageOkText4,
        ),
        content: Text(
          _source == 'remote'
              ? l10n.lyricsLibraryPageOkText9((_selected.length).toString())
              : l10n.lyricsLibraryPageOkText8((_selected.length).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_source == 'remote' ? l10n.remove : l10n.delete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      if (_source == 'remote') {
        await _service.removeOnlineWorks(Set.of(_selected));
      } else {
        await _service.deleteWorks(Set.of(_selected));
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selecting = false;
      });
      if (_source == 'remote') {
        await _reloadRecords();
      } else {
        await _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  /// 索引会在导入、删除和刷新后保存。优先用它绘制首屏，避免每次进入
  /// 页面都等待整个歌词目录的递归扫描完成。
  Future<void> _loadInitialRecords() async {
    final records = await _service.records();
    if (!mounted) return;
    _applyRecords(records);

    if (records.isEmpty) {
      // 首次使用时没有索引，只能立即扫描以发现已有的歌词目录。
      if (_source == 'local') await _refresh();
      return;
    }

    // 确保缓存内容至少完成一帧绘制后才扫描磁盘；扫描期间仍保留已显示的
    // 条目，外部新增或删除的文件夹会在后台同步回来。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _source == 'local') _refresh();
    });
  }

  void _applyRecords(List<LyricsLibraryRecord> records) {
    final directoryCounts = <String, int>{};
    final aiWorkIds = <String>{};
    final translatedWorkIds = <String>{};
    final onlineWorkIds = <String>{};
    for (final record in records) {
      if (record.online != (_source == 'remote')) continue;
      if (record.isTranslated) translatedWorkIds.add(record.workId);
      final firstForWork = !directoryCounts.containsKey(record.workId);
      directoryCounts.update(
        record.workId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (record.isAi && (!record.online || firstForWork)) {
        aiWorkIds.add(record.workId);
      }
      if (record.online) onlineWorkIds.add(record.workId);
    }
    final ids = directoryCounts.keys.toList()..sort();
    _searchTimer?.cancel();
    final filtered = _filterWorkIds(ids, aiWorkIds);
    ++_countLoadToken;
    setState(() {
      _workIds = ids;
      _filteredWorkIds = filtered;
      _directoryCounts = directoryCounts;
      _aiWorkIds = aiWorkIds;
      _translatedWorkIds = translatedWorkIds;
      _onlineWorkIds = onlineWorkIds;
      _files = {};
      _fileCounts.clear();
      _countFailures.clear();
      _visibleCount = _batchSize;
      _loadingMore = false;
    });
    _loadCounts(filtered.take(_batchSize).toList());
  }

  List<String> _filterWorkIds(List<String> ids, Set<String> aiWorkIds) {
    final query = _search.text.trim().toUpperCase();
    if (query.isEmpty && !_aiOnly) return ids;
    return ids
        .where(
          (id) => (!_aiOnly || aiWorkIds.contains(id)) && id.contains(query),
        )
        .toList();
  }

  void _setAiOnly(bool? value) {
    if (value == null || value == _aiOnly) return;
    _searchTimer?.cancel();
    _aiOnly = value;
    _updateSearchResults();
    if (_selected.isNotEmpty) {
      _selected.retainAll(_filteredWorkIds.toSet());
    }
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    if (_search.text.trim().isEmpty) {
      _updateSearchResults();
    } else {
      // Keep typing responsive without filtering the full index every keypress.
      setState(() {});
      _searchTimer = Timer(
        const Duration(milliseconds: 180),
        _updateSearchResults,
      );
    }
  }

  void _updateSearchResults() {
    if (!mounted) return;
    final filtered = _filterWorkIds(_workIds, _aiWorkIds);
    ++_countLoadToken;
    setState(() {
      _filteredWorkIds = filtered;
      _visibleCount = _batchSize;
      _loadingMore = false;
    });
    _loadCounts(
      filtered
          .take(_batchSize)
          .where((id) => !_fileCounts.containsKey(id))
          .toList(),
    );
  }

  Future<void> _changeSource(String source) async {
    if (!mounted || source == _source) return;
    ++_refreshGeneration;
    ++_countLoadToken;
    setState(() {
      _source = source;
      _loading = false;
      _loadingMore = false;
      _selected.clear();
      _selecting = false;
    });
    final records = await _service.records();
    if (!mounted || _source != source) return;
    _applyRecords(records);
  }

  Future<void> _reloadRecords() async {
    final records = await _service.records();
    if (mounted) _applyRecords(records);
  }

  Future<void> _onRemoteLibraryChanged(bool switchToRemote) async {
    if (switchToRemote && _source != 'remote') {
      await _changeSource('remote');
    } else {
      await _reloadRecords();
    }
  }

  Future<void> _refresh({bool deep = false}) async {
    final l10n = context.l10n;
    if (_loading && !deep) return;
    final source = _source;
    final generation = ++_refreshGeneration;
    setState(() => _loading = true);
    try {
      bool shouldCancel() => !mounted || generation != _refreshGeneration;
      final records = source == 'remote'
          ? await _service.refreshRemoteLibraries(shouldCancel: shouldCancel)
          : await _service.refresh(
              deep: deep,
              shouldCancel: deep ? null : shouldCancel,
            );
      if (mounted && generation == _refreshGeneration) {
        _applyRecords(records);
      }
    } catch (error) {
      if (mounted && generation == _refreshGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.lyricsLibraryPageRefreshText((error).toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCounts(List<String> ids) async {
    if (ids.isEmpty) return;
    final token = _countLoadToken;
    try {
      final result = await _service.countFilesForWorks(ids);
      if (!mounted || token != _countLoadToken) return;
      setState(() {
        _fileCounts.addAll(result);
        _countFailures.removeAll(result.keys);
      });
    } catch (_) {
      if (!mounted || token != _countLoadToken) return;
      setState(() {
        _countFailures.addAll(ids.where((id) => !_fileCounts.containsKey(id)));
      });
    }
  }

  Future<void> _loadNextBatch(List<String> ids) async {
    if (_loadingMore || _visibleCount >= ids.length) return;
    final token = _countLoadToken;
    final start = _visibleCount;
    final end = (start + _batchSize).clamp(0, ids.length);
    setState(() {
      _loadingMore = true;
      _visibleCount = end;
    });
    try {
      await _loadCounts(ids.sublist(start, end));
    } finally {
      if (mounted && token == _countLoadToken) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    if (_importing) return;
    setState(() => _importing = true);
    // Android 上文件夹会被镜像到应用缓存目录，导入结束后需要清理。
    String? mirroredDirectory;
    try {
      final kind = await showDialog<String>(
        context: context,
        builder: (_) => _LyricsLibraryImportDialog(
          service: _service,
          onRemoteChanged: _onRemoteLibraryChanged,
        ),
      );
      if (kind == null) return;
      final paths = <String>[];
      final sourceNames = <String, String>{};
      if (kind == 'zip') {
        final result = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['zip'],
          dialogTitle: l10n.lyricsLibraryPageResultDialogTitle,
        );
        for (final file in result?.files ?? const <PlatformFile>[]) {
          final path = file.path;
          if (path == null) continue;
          paths.add(path);
          sourceNames[path] = file.name;
        }
      } else {
        final selection = await LyricsFolderImport.pickDirectory(
          dialogTitle: l10n.lyricsLibraryPageSelectionDialogTitle,
        );
        if (!mounted) return;
        final dir = selection.path;
        if (dir == null) return;
        // 只有 Android 走缓存镜像；桌面端选中的是用户自己的目录，不能删。
        if (LyricsFolderImport.usesSaf) mirroredDirectory = dir;
        if (selection.fileCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.lyricsLibraryPageImportText6)),
          );
          return;
        }
        paths.add(dir);
      }
      if (paths.isEmpty) return;
      final largeImport = await _service.isLargeImport(paths);
      if (!mounted) return;
      if (largeImport) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.lyricsLibraryPageProceedText2),
            content: Text(l10n.lyricsLibraryPageProceedText3),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.lyricsLibraryPageProceedText),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (proceed != true) return;
      }
      final scanProgress = ValueNotifier<LyricsImportProgress>(
        LyricsImportProgress(
          phase: l10n.lyricsLibraryPageScanProgressPhase,
          current: 0,
          total: 0,
        ),
      );
      final scanNavigator = Navigator.of(context, rootNavigator: true);
      final scanDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(progress: scanProgress),
      );
      List<String> conflicts;
      try {
        conflicts = await _service.findConflicts(
          paths,
          sourceNames: sourceNames,
          onProgress: (value) => scanProgress.value = value,
        );
      } finally {
        if (scanNavigator.mounted) scanNavigator.pop();
        scanProgress.dispose();
      }
      await scanDialog;
      if (!mounted) return;
      var conflict = LyricsImportConflict.skip;
      if (conflicts.isNotEmpty) {
        conflict =
            await showDialog<LyricsImportConflict>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.lyricsLibraryPageImportText4),
                content: Text(
                  l10n.lyricsLibraryPageImportText7(
                    (conflicts.length).toString(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, LyricsImportConflict.cancel),
                    child: Text(l10n.lyricsLibraryPageImportText),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, LyricsImportConflict.skip),
                    child: Text(l10n.lyricsLibraryPageImportText2),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, LyricsImportConflict.overwrite),
                    child: Text(l10n.lyricsLibraryPageImportText3),
                  ),
                ],
              ),
            ) ??
            LyricsImportConflict.cancel;
      }
      if (!mounted) return;
      if (conflict == LyricsImportConflict.cancel) return;
      final progress = ValueNotifier<LyricsImportProgress>(
        LyricsImportProgress(
          phase: l10n.lyricsLibraryPageProgressPhase,
          current: 0,
          total: 0,
        ),
      );
      final progressNavigator = Navigator.of(context, rootNavigator: true);
      final progressDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(progress: progress),
      );
      try {
        await _service.importPaths(
          paths,
          sourceNames: sourceNames,
          conflict: conflict,
          onProgress: (value) => progress.value = value,
        );
      } finally {
        if (progressNavigator.mounted) progressNavigator.pop();
        progress.dispose();
      }
      await progressDialog;
      if (_source != 'local') {
        await _changeSource('local');
      } else {
        await _reloadRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lyricsLibraryPageImportText5((e).toString())),
          ),
        );
      }
    } finally {
      await LyricsFolderImport.releaseDirectory(mirroredDirectory);
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deepRefresh() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.lyricsLibraryPageOkText),
        content: Text(l10n.lyricsLibraryPageOkText7),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (ok == true) await _refresh(deep: true);
  }

  Future<void> _showFiles(String workId) async {
    final l10n = context.l10n;
    final token = _countLoadToken;
    final request = ++_fileListRequest;
    bool isCurrent() => token == _countLoadToken && request == _fileListRequest;
    try {
      final cached = _files[workId];
      final files =
          cached ??
          (_onlineWorkIds.contains(workId)
              ? (await _service.remoteFilesForWork(workId))
                    .map(
                      (file) => LyricsLibraryFile(
                        workId: workId,
                        relativePath: file.relativePath,
                        name: file.name,
                        extension: file.extension,
                        absolutePath: '',
                      ),
                    )
                    .toList()
              : await _service.listFiles(workId: workId));
      if (!mounted || !isCurrent()) return;
      setState(() {
        _files[workId] = files;
        _fileCounts[workId] = files.length;
        _countFailures.remove(workId);
      });
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: 420,
            child: files.isEmpty
                ? Center(child: Text(l10n.lyricsLibraryPageShowFilesText))
                : SmoothListView.builder(
                    itemCount: files.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.lyrics_outlined),
                      title: Text(files[i].name),
                      subtitle: Text(files[i].relativePath),
                    ),
                  ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lyricsLibraryPageShowFilesText2)),
      );
    }
  }

  Future<void> _confirmDeleteWork(String workId) async {
    final l10n = context.l10n;
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _source == 'remote'
              ? l10n.lyricsLibraryPageOkText3
              : l10n.lyricsLibraryPageOkText2,
        ),
        content: Text(
          _source == 'remote'
              ? l10n.lyricsLibraryPageOkText5((workId).toString())
              : l10n.lyricsLibraryPageOkText6((workId).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_source == 'remote' ? l10n.remove : l10n.delete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      if (_source == 'remote') {
        await _service.removeOnlineWorks({workId});
      } else {
        await _service.deleteWorks({workId});
      }
      if (mounted) {
        if (_source == 'remote') {
          await _reloadRecords();
        } else {
          await _refresh();
        }
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final ids = _filteredWorkIds;
    final visibleCount = _visibleCount.clamp(0, ids.length);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 112,
        leading: _selecting
            ? Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.exitSelection,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _toggleSelecting,
                  ),
                  Text(
                    context.l10n.lyricsLibraryPageBuildText8(
                      (_aiOnly ? ids.length : _workIds.length).toString(),
                    ),
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ],
              )
            : Row(
                children: [
                  const BackButton(),
                  Text(
                    context.l10n.lyricsLibraryPageBuildText8(
                      (_aiOnly ? ids.length : _workIds.length).toString(),
                    ),
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ],
              ),
        title: Text(context.l10n.lyricsLibrary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Pill(
                    label: context.l10n.local,
                    selected: _source == 'local',
                    onTap: () => _changeSource('local'),
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    label: context.l10n.online,
                    selected: _source == 'remote',
                    onTap: () => _changeSource('remote'),
                  ),
                  const Spacer(),
                  MergeSemantics(
                    child: InkWell(
                      onTap: () => _setAiOnly(!_aiOnly),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _aiOnly,
                            onChanged: _setAiOnly,
                            activeColor: p.accent,
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(
                            context.l10n.widgetsBuildBuilder,
                            style: TextStyle(fontSize: 12.5, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (_searching)
            IconButton(
              tooltip: context.l10n.downloadsPageBuildTooltip,
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _searching = false);
                _search.clear();
                _onSearchChanged();
              },
            )
          else
            IconButton(
              tooltip: context.l10n.lyricsLibraryPageBuildTooltip,
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _searching = true;
                  _visibleCount = _batchSize;
                });
                _searchFocus.requestFocus();
              },
            ),
          if (_selecting) ...[
            IconButton(
              tooltip: context.l10n.downloadsPageBuildTooltip2,
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty || _deleting
                  ? null
                  : _deleteSelected,
            ),
            IconButton(
              tooltip: _selected.length == ids.length
                  ? context.l10n.deselectAll
                  : context.l10n.selectAll,
              icon: Icon(
                _selected.length == ids.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () => _selectAll(ids),
            ),
          ],
          IconButton(
            tooltip: _selecting
                ? context.l10n.exitSelection
                : context.l10n.selectMultiple,
            icon: Icon(_selecting ? Icons.close : Icons.checklist_outlined),
            onPressed: _toggleSelecting,
          ),
          Semantics(
            button: true,
            label: _source == 'remote'
                ? context.l10n.lyricsLibraryPageBuildLabel2
                : context.l10n.lyricsLibraryPageBuildLabel,
            hint: _source == 'remote'
                ? context.l10n.lyricsLibraryPageBuildHint2
                : context.l10n.lyricsLibraryPageBuildHint,
            child: InkResponse(
              onTap: _loading || _importing || _deleting ? null : _refresh,
              onLongPress:
                  _source == 'remote' || _loading || _importing || _deleting
                  ? null
                  : _deepRefresh,
              radius: 24,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _importing || _loading || _deleting ? null : _import,
            icon: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_folder_upload_outlined),
            tooltip: context.l10n.importAction,
          ),
        ],
      ),
      body: SubpageSwipe(
        index: _source == 'local' ? 0 : 1,
        count: 2,
        onChanged: (index) => _changeSource(index == 0 ? 'local' : 'remote'),
        child: Column(
          children: [
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _searchField(p),
              ),
            Expanded(
              child: ids.isEmpty
                  ? Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Text(
                              _aiOnly
                                  ? context.l10n.homePageEmptyHintText4
                                  : _source == 'remote'
                                  ? context.l10n.lyricsLibraryPageBuildText9
                                  : context.l10n.lyricsLibraryPageBuildText6,
                            ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final count = (constraints.maxWidth / 210)
                            .floor()
                            .clamp(2, 8);
                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent - 240) {
                              _loadNextBatch(ids);
                            }
                            return false;
                          },
                          child: SmoothGridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  crossAxisSpacing: 13,
                                  mainAxisSpacing: 13,
                                  childAspectRatio: 3.15,
                                ),
                            itemCount: visibleCount,
                            itemBuilder: (_, i) {
                              final id = ids[i];
                              final fileCount = _fileCounts[id];
                              final directoryCount = _directoryCounts[id] ?? 0;
                              final isAi = _aiWorkIds.contains(id);
                              final isTranslated = _translatedWorkIds.contains(
                                id,
                              );
                              final isOnline = _onlineWorkIds.contains(id);
                              return Stack(
                                children: [
                                  InkWell(
                                    onTap: () => _selecting
                                        ? _toggleSelection(id)
                                        : _showFiles(id),
                                    onLongPress: _selecting
                                        ? null
                                        : () => _confirmDeleteWork(id),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 72,
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        10,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.surface2,
                                        border: Border.all(color: p.border),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: p.accent.withValues(
                                                alpha: .14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.lyrics_outlined,
                                              size: 19,
                                              color: p.accent,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  id,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: p.text,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  fileCount == null
                                                      ? (_countFailures
                                                                .contains(id)
                                                            ? context
                                                                  .l10n
                                                                  .lyricsLibraryPageBuildText5
                                                            : context
                                                                  .l10n
                                                                  .lyricsLibraryPageBuildText4)
                                                      : context.l10n.lyricsLibraryPageBuildText10(
                                                          (fileCount)
                                                              .toString(),
                                                          (isOnline
                                                                  ? context
                                                                        .l10n
                                                                        .remote
                                                                  : context.l10n.lyricsLibraryPageBuildText7(
                                                                      (directoryCount)
                                                                          .toString(),
                                                                    ))
                                                              .toString(),
                                                        ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: p.muted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isAi || isOnline || isTranslated)
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isTranslated)
                                                  _sourceBadge('TL', p.accent)
                                                else if (isAi)
                                                  _sourceBadge('AI', p.accent),
                                                if (isOnline &&
                                                    !isTranslated) ...[
                                                  if (isAi)
                                                    const SizedBox(height: 3),
                                                  _sourceBadge(
                                                    context.l10n.online,
                                                    p.orange,
                                                  ),
                                                ],
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_selecting)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Checkbox(
                                        value: _selected.contains(id),
                                        onChanged: (_) => _toggleSelection(id),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sourceBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );

  Widget _searchField(Palette p) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      padding: const EdgeInsets.only(left: 13, right: 8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.accent),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 19, color: p.dim),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: p.text),
              decoration: InputDecoration(
                hintText: context.l10n.lyricsLibraryPageSearchFieldHintText,
                hintStyle: TextStyle(fontSize: 14, color: p.dim),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
          ),
          if (_search.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                _onSearchChanged();
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: p.surface3,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _LyricsLibraryImportDialog extends StatefulWidget {
  final LyricsLibraryService service;
  final Future<void> Function(bool switchToRemote) onRemoteChanged;

  const _LyricsLibraryImportDialog({
    required this.service,
    required this.onRemoteChanged,
  });

  @override
  State<_LyricsLibraryImportDialog> createState() =>
      _LyricsLibraryImportDialogState();
}

class _LyricsLibraryImportDialogState
    extends State<_LyricsLibraryImportDialog> {
  final _url = TextEditingController();
  String _section = 'local';
  String? _error;
  bool _connecting = false;
  bool _reordering = false;
  String? _refreshingUrl;
  String? _removingUrl;
  List<String> _remoteUrls = [];

  bool get _busy =>
      _connecting ||
      _reordering ||
      _refreshingUrl != null ||
      _removingUrl != null;

  @override
  void initState() {
    super.initState();
    _loadRemoteSources();
  }

  Future<void> _loadRemoteSources() async {
    final urls = await widget.service.remoteLibraryUrls();
    final lastUrl = await widget.service.lastRemoteUrl;
    if (!mounted) return;
    setState(() => _remoteUrls = urls);
    if (_url.text.isEmpty) _url.text = lastUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await widget.service.connectRemoteLibrary(_url.text);
      await widget.onRemoteChanged(true);
      final urls = await widget.service.remoteLibraryUrls();
      if (mounted) {
        _url.clear();
        setState(() => _remoteUrls = urls);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _refreshOne(String url) async {
    final l10n = context.l10n;
    if (_busy) return;
    setState(() {
      _refreshingUrl = url;
      _error = null;
    });
    try {
      await widget.service.refreshRemoteLibrary(url);
      await widget.onRemoteChanged(false);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.lyricsLibraryPageRefreshOneSetState(
            (url).toString(),
            (error).toString(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingUrl = null);
    }
  }

  Future<void> _removeRemoteLibrary(String url) async {
    final l10n = context.l10n;
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.lyricsLibraryPageConfirmedText),
        content: Text(l10n.lyricsLibraryPageConfirmedText2((url).toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _removingUrl = url;
      _error = null;
    });
    try {
      await widget.service.removeRemoteLibrary(url);
      await widget.onRemoteChanged(false);
      final urls = await widget.service.remoteLibraryUrls();
      if (mounted) setState(() => _remoteUrls = urls);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = l10n.lyricsLibraryPageRemoveRemoteLibrarySetState(
            (url).toString(),
            (error).toString(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removingUrl = null);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final l10n = context.l10n;
    if (_busy) return;
    if (oldIndex == newIndex) return;
    final previous = List<String>.of(_remoteUrls);
    final reordered = List<String>.of(previous);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _remoteUrls = reordered;
      _reordering = true;
      _error = null;
    });
    try {
      await widget.service.setRemoteLibraryOrder(reordered);
      await widget.onRemoteChanged(false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _remoteUrls = previous;
          _error = l10n.lyricsLibraryPageReorderSetState((error).toString());
        });
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Widget _navItem(String key, String label, IconData icon) {
    final selected = _section == key;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: colors.primary.withValues(alpha: .1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, size: 19, color: selected ? colors.primary : null),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        onTap: () => setState(() {
          _section = key;
          _error = null;
        }),
      ),
    );
  }

  Widget _remoteSourceList() {
    if (_remoteUrls.isEmpty) {
      return SizedBox(
        height: 84,
        child: Center(
          child: Text(context.l10n.lyricsLibraryPageRemoteSourceListText),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.zero,
        itemCount: _remoteUrls.length,
        onReorderItem: _reorder,
        itemBuilder: (context, index) {
          final url = _remoteUrls[index];
          return Card(
            key: ValueKey(url),
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4, right: 2),
              leading: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, size: 20),
                ),
              ),
              title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                context.l10n.lyricsLibraryPageRemoteSourceListText2(
                  (index + 1).toString(),
                ),
              ),
              onLongPress: _busy ? null : () => _removeRemoteLibrary(url),
              trailing: IconButton(
                tooltip: context.l10n.lyricsLibraryPageRemoteSourceListTooltip,
                onPressed: _busy ? null : () => _refreshOne(url),
                icon: _refreshingUrl == url || _removingUrl == url
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final contentHeight =
        (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                160)
            .clamp(240.0, 420.0)
            .toDouble();
    final sectionContent = _section == 'local'
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.lyricsLibraryPageSectionContentText5,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, 'folder'),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(context.l10n.lyricsLibraryPageSectionContentText),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'zip'),
                icon: const Icon(Icons.archive_outlined),
                label: Text(context.l10n.lyricsLibraryPageSectionContentText4),
              ),
            ],
          )
        : SmoothSingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.lyricsLibraryPageSectionContentText6,
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _url,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.lyricsLibraryPageSectionContentLabelText,
                    hintText: 'http://192.168.1.20:2377',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    _connecting
                        ? context.l10n.lyricsLibraryPageSectionContentText3
                        : context.l10n.lyricsLibraryPageSectionContentText2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.l10n.lyricsLibraryPageSectionContentText8,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Divider(height: 22),
                Text(
                  context.l10n.lyricsLibraryPageSectionContentText7,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 7),
                _remoteSourceList(),
              ],
            ),
          );
    return AlertDialog(
      title: Text(context.l10n.lyricsLibraryPageBuildText),
      content: SizedBox(
        width: 520,
        height: contentHeight,
        child: isPortrait
            ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'local',
                          label: Text(
                            context.l10n.lyricsLibraryPageBuildNavItem2,
                          ),
                          icon: Icon(Icons.folder_open_outlined),
                        ),
                        ButtonSegment(
                          value: 'remote',
                          label: Text(
                            context.l10n.lyricsLibraryPageBuildNavItem,
                          ),
                          icon: Icon(Icons.cloud_outlined),
                        ),
                      ],
                      selected: {_section},
                      onSelectionChanged: (selection) => setState(() {
                        _section = selection.first;
                        _error = null;
                      }),
                    ),
                  ),
                  const Divider(height: 20),
                  Expanded(child: sectionContent),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _navItem(
                          'local',
                          context.l10n.lyricsLibraryPageBuildNavItem2,
                          Icons.folder_open_outlined,
                        ),
                        _navItem(
                          'remote',
                          context.l10n.lyricsLibraryPageBuildNavItem,
                          Icons.cloud_outlined,
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 20),
                  Expanded(child: sectionContent),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
  final ValueListenable<LyricsImportProgress> progress;

  const _ImportProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.lyricsLibraryPageBuildText2),
      content: SizedBox(
        width: 340,
        child: ValueListenableBuilder<LyricsImportProgress>(
          valueListenable: progress,
          builder: (context, value, _) {
            final percent = value.value == null
                ? ''
                : ' ${(value.value! * 100).round()}%';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.phase,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '$percent${value.total > 0 ? '  ${value.current}/${value.total}' : ''}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: value.value),
                const SizedBox(height: 10),
                Text(
                  value.currentPath?.split(RegExp(r'[/\\]')).last ??
                      context.l10n.lyricsLibraryPageBuildText3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
