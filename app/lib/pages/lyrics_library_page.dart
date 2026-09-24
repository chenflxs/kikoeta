import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/lyrics_library_service.dart';
import '../theme.dart';
import '../widgets.dart';

class LyricsLibraryPage extends StatefulWidget {
  const LyricsLibraryPage({super.key});

  @override
  State<LyricsLibraryPage> createState() => _LyricsLibraryPageState();
}

class _LyricsLibraryPageState extends State<LyricsLibraryPage> {
  static const _batchSize = 50;
  final _service = LyricsLibraryService.instance;
  List<String> _workIds = [];
  Map<String, int> _directoryCounts = {};
  Set<String> _aiWorkIds = {};
  Set<String> _onlineWorkIds = {};
  Map<String, List<LyricsLibraryFile>> _files = {};
  String _source = 'local';
  bool _loading = false;
  bool _importing = false;
  bool _deleting = false;
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _searching = false;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Map<String, int> _fileCounts = {};
  int _countLoadToken = 0;
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
    if (_selected.isEmpty || _deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_source == 'remote' ? '移除远程作品' : '删除歌词库作品'),
        content: Text(
          _source == 'remote'
              ? '确定移除选中的 ${_selected.length} 个远程作品索引吗？'
              : '确定删除选中的 ${_selected.length} 个作品目录吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_source == 'remote' ? '移除' : '删除'),
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
    final localRecords = records.where((record) => !record.online).toList();
    final remoteRecords = records.where((record) => record.online).toList();
    final sourceRecords = _source == 'remote' ? remoteRecords : localRecords;
    final directoryCounts = <String, int>{};
    final aiWorkIds = <String>{};
    final onlineWorkIds = <String>{};
    for (final record in sourceRecords) {
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
    setState(() {
      _workIds = ids;
      _directoryCounts = directoryCounts;
      _aiWorkIds = aiWorkIds;
      _onlineWorkIds = onlineWorkIds;
      _files = {};
      _fileCounts.clear();
      _visibleCount = _batchSize;
    });
    _loadCounts(ids.take(_batchSize).toList());
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刷新失败：$error')));
      }
    } finally {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCounts(List<String> ids) async {
    final token = ++_countLoadToken;
    final result = await _service.countFilesForWorks(ids);
    if (!mounted || token != _countLoadToken) return;
    setState(() => _fileCounts.addAll(result));
  }

  Future<void> _loadNextBatch(List<String> ids) async {
    if (_loadingMore || _visibleCount >= ids.length) return;
    final start = _visibleCount;
    final end = (start + _batchSize).clamp(0, ids.length);
    setState(() {
      _loadingMore = true;
      _visibleCount = end;
    });
    await _loadCounts(ids.sublist(start, end));
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
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
          dialogTitle: '选择 ZIP 文件',
        );
        for (final file in result?.files ?? const <PlatformFile>[]) {
          final path = file.path;
          if (path == null) continue;
          paths.add(path);
          sourceNames[path] = file.name;
        }
      } else {
        final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择歌词文件夹');
        if (dir != null) paths.add(dir);
      }
      if (paths.isEmpty) return;
      final largeImport = await _service.isLargeImport(paths);
      if (!mounted) return;
      if (largeImport) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('大型内容导入'),
            content: const Text('检测到大型压缩包或文件夹，导入过程可能需要较长时间，请耐心等待。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续导入'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (proceed != true) return;
      }
      final scanProgress = ValueNotifier<LyricsImportProgress>(
        const LyricsImportProgress(phase: '正在检查文件冲突', current: 0, total: 0),
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
                title: const Text('发现导入冲突'),
                content: Text('检测到 ${conflicts.length} 个已存在文件，如何处理？'),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, LyricsImportConflict.cancel),
                    child: const Text('取消导入'),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, LyricsImportConflict.skip),
                    child: const Text('跳过冲突文件'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, LyricsImportConflict.overwrite),
                    child: const Text('覆盖冲突文件'),
                  ),
                ],
              ),
            ) ??
            LyricsImportConflict.cancel;
      }
      if (!mounted) return;
      if (conflict == LyricsImportConflict.cancel) return;
      final progress = ValueNotifier<LyricsImportProgress>(
        const LyricsImportProgress(phase: '准备导入', current: 0, total: 0),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deepRefresh() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('深度刷新'),
        content: const Text('将删除没有歌词或字幕文件的作品目录，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (ok == true) await _refresh(deep: true);
  }

  Future<void> _showFiles(String workId) async {
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
    if (cached == null && mounted) {
      setState(() => _files[workId] = files);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 420,
          child: files.isEmpty
              ? const Center(child: Text('没有可用的歌词或字幕文件'))
              : ListView.builder(
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
  }

  Future<void> _confirmDeleteWork(String workId) async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_source == 'remote' ? '移除远程作品' : '删除歌词'),
        content: Text(
          _source == 'remote'
              ? '确定移除 $workId 的远程作品索引吗？'
              : '确定删除 $workId 的全部歌词文件吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_source == 'remote' ? '移除' : '删除'),
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
    final query = _search.text.trim().toLowerCase();
    final ids = _workIds
        .where((id) => query.isEmpty || id.toLowerCase().contains(query))
        .toList();
    final visibleIds = ids.take(_visibleCount).toList();
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 112,
        leading: _selecting
            ? Row(
                children: [
                  IconButton(
                    tooltip: '退出多选',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _toggleSelecting,
                  ),
                  Text(
                    '${_workIds.length} 个',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ],
              )
            : Row(
                children: [
                  const BackButton(),
                  Text(
                    '${_workIds.length} 个',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ],
              ),
        title: const Text('歌词库'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pill(
                    label: '本地',
                    selected: _source == 'local',
                    onTap: () => _changeSource('local'),
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    label: '在线',
                    selected: _source == 'remote',
                    onTap: () => _changeSource('remote'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (_searching)
            IconButton(
              tooltip: '关闭搜索',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searching = false;
                _search.clear();
                _visibleCount = _batchSize;
              }),
            )
          else
            IconButton(
              tooltip: '搜索歌词库',
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
              tooltip: '删除选中作品',
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
              tooltip: _selected.length == ids.length ? '取消全选' : '全选',
              icon: Icon(
                _selected.length == ids.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () => _selectAll(ids),
            ),
          ],
          IconButton(
            tooltip: _selecting ? '退出多选' : '多选',
            icon: Icon(_selecting ? Icons.close : Icons.checklist_outlined),
            onPressed: _toggleSelecting,
          ),
          Semantics(
            button: true,
            label: _source == 'remote' ? '刷新全部远程库' : '刷新歌词库',
            hint: _source == 'remote' ? '同步所有已导入远程库的作品索引' : '长按执行深度刷新',
            child: InkResponse(
              onTap: _loading || _importing || _deleting ? null : _refresh,
              onLongPress: _source == 'remote' ||
                      _loading ||
                      _importing ||
                      _deleting
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
            tooltip: '导入',
          ),
        ],
      ),
      body: Column(
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
                            _source == 'remote'
                                ? '暂无远程作品，点击右上角导入并连接远程库'
                                : '暂无数据，点击右上角导入',
                          ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final count = (constraints.maxWidth / 210).floor().clamp(
                        2,
                        8,
                      );
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 240) {
                            _loadNextBatch(ids);
                          }
                          return false;
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                crossAxisSpacing: 13,
                                mainAxisSpacing: 13,
                                childAspectRatio: 3.15,
                              ),
                          itemCount: visibleIds.length,
                          itemBuilder: (_, i) {
                            final id = visibleIds[i];
                            final fileCount = _fileCounts[id];
                            final directoryCount = _directoryCounts[id] ?? 0;
                            final isAi = _aiWorkIds.contains(id);
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: p.text,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                fileCount == null
                                                    ? '正在统计歌词文件'
                                                    : '$fileCount 个歌词/字幕文件 · ${isOnline ? '远程' : '$directoryCount 个目录'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: p.muted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isAi || isOnline)
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isAi)
                                                _sourceBadge('AI', p.accent),
                                              if (isOnline) ...[
                                                if (isAi)
                                                  const SizedBox(height: 3),
                                                _sourceBadge('在线', p.orange),
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
                hintText: '搜索作品 ID',
                hintStyle: TextStyle(fontSize: 14, color: p.dim),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (_) => setState(() {
                _visibleCount = _batchSize;
              }),
            ),
          ),
          if (_search.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                setState(() {
                  _visibleCount = _batchSize;
                });
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
  List<String> _remoteUrls = [];

  bool get _busy => _connecting || _reordering || _refreshingUrl != null;

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
    if (_busy) return;
    setState(() {
      _refreshingUrl = url;
      _error = null;
    });
    try {
      await widget.service.refreshRemoteLibrary(url);
      await widget.onRemoteChanged(false);
    } catch (error) {
      if (mounted) setState(() => _error = '刷新 $url 失败：$error');
    } finally {
      if (mounted) setState(() => _refreshingUrl = null);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
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
          _error = '调整优先级失败：$error';
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
      return const SizedBox(
        height: 84,
        child: Center(child: Text('尚未导入远程库')),
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
              subtitle: Text('优先级 ${index + 1}'),
              trailing: IconButton(
                tooltip: '只刷新此远程库',
                onPressed: _busy ? null : () => _refreshOne(url),
                icon: _refreshingUrl == url
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
    final contentHeight = (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom -
            160)
        .clamp(240.0, 420.0)
        .toDouble();
    return AlertDialog(
      title: const Text('导入歌词库'),
      content: SizedBox(
        width: 520,
        height: contentHeight,
        child: Row(
          children: [
            SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _navItem('local', '本地文件', Icons.folder_open_outlined),
                  _navItem('remote', '远程库', Icons.cloud_outlined),
                ],
              ),
            ),
            const VerticalDivider(width: 20),
            Expanded(
              child: _section == 'local'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '选择要导入的歌词文件或压缩包。',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.pop(context, 'folder'),
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('选择文件夹'),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context, 'zip'),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('选择 ZIP 压缩包'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '输入开启了歌词库广播的设备地址。',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _url,
                            autofocus: true,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'HTTP / HTTPS 地址',
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.link),
                            label: Text(_connecting ? '正在连接并同步' : '导入远程库'),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '导入时只同步作品索引；播放时再下载该作品的全部歌词。',
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
                          const Text(
                            '已导入的远程库（从上到下优先级递减，拖动排序）',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 7),
                          _remoteSourceList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
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
      title: const Text('正在导入歌词'),
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
                  value.currentPath?.split(RegExp(r'[/\\]')).last ?? '正在准备文件…',
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
