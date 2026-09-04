import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/lyrics_library_service.dart';
import '../theme.dart';

class LyricsLibraryPage extends StatefulWidget {
  const LyricsLibraryPage({super.key});

  @override
  State<LyricsLibraryPage> createState() => _LyricsLibraryPageState();
}

class _LyricsLibraryPageState extends State<LyricsLibraryPage> {
  static const _batchSize = 50;
  final _service = LyricsLibraryService.instance;
  List<LyricsLibraryRecord> _records = [];
  Map<String, List<LyricsLibraryFile>> _files = {};
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

  @override
  void initState() {
    super.initState();
    _refresh();
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
        title: const Text('删除歌词库作品'),
        content: Text('确定删除选中的 ${_selected.length} 个作品目录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await _service.deleteWorks(Set.of(_selected));
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selecting = false;
      });
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _refresh({bool deep = false}) async {
    if (_loading && !deep) return;
    setState(() => _loading = true);
    try {
      final records = await _service.refresh(deep: deep);
      if (mounted) {
        setState(() {
          _records = records;
          _files = {};
          _fileCounts.clear();
          _visibleCount = _batchSize;
        });
        final ids = records.map((e) => e.workId).toSet().toList()..sort();
        _loadCounts(ids.take(_batchSize).toList());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCounts(List<String> ids) async {
    final token = ++_countLoadToken;
    final result = <String, int>{};
    await Future.wait(
      ids.map((id) async {
        result[id] = (await _service.listFiles(workId: id)).length;
      }),
    );
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
        builder: (ctx) => AlertDialog(
          title: const Text('选择导入内容'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'folder'),
              child: const Text('文件夹'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'zip'),
              child: const Text('ZIP 压缩包'),
            ),
          ],
        ),
      );
      if (kind == null) return;
      final paths = <String>[];
      if (kind == 'zip') {
        final result = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['zip'],
          dialogTitle: '选择 ZIP 文件',
        );
        paths.addAll(
          result?.files.map((file) => file.path).whereType<String>().toList() ??
              const <String>[],
        );
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
        if (proceed != true) return;
      }
      final scanProgress = ValueNotifier<LyricsImportProgress>(
        const LyricsImportProgress(phase: '正在检查文件冲突', current: 0, total: 0),
      );
      final scanDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(progress: scanProgress),
      );
      List<String> conflicts;
      try {
        conflicts = await _service.findConflicts(paths);
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
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
      if (conflict == LyricsImportConflict.cancel) return;
      final progress = ValueNotifier<LyricsImportProgress>(
        const LyricsImportProgress(phase: '准备导入', current: 0, total: 0),
      );
      final progressDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(progress: progress),
      );
      try {
        await _service.importPaths(
          paths,
          conflict: conflict,
          onProgress: (value) => progress.value = value,
        );
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        progress.dispose();
      }
      await progressDialog;
      await _refresh();
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
    final files = cached ?? await _service.listFiles(workId: workId);
    if (cached == null && mounted) {
      setState(() => _files[workId] = files);
    }
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
        title: const Text('删除歌词'),
        content: Text('确定删除 $workId 的全部歌词文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await _service.deleteWorks({workId});
      if (mounted) await _refresh();
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
    final ids =
        _records
            .map((e) => e.workId)
            .toSet()
            .where((id) => query.isEmpty || id.toLowerCase().contains(query))
            .toList()
          ..sort();
    final visibleIds = ids.take(_visibleCount).toList();
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                tooltip: '退出多选',
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSelecting,
              )
            : const BackButton(),
        title: const Text('歌词库'),
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
          GestureDetector(
            onLongPress: _loading || _importing || _deleting
                ? null
                : _deepRefresh,
            child: IconButton(
              onPressed: _loading || _importing || _deleting ? null : _refresh,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: '刷新',
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
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索作品 ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {
                  _visibleCount = _batchSize;
                }),
              ),
            ),
          Expanded(
            child: ids.isEmpty
                ? const Center(child: Text('暂无数据，点击右上角导入'))
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
                            final records = _records
                                .where((e) => e.workId == id)
                                .toList();
                            final fileCount = _fileCounts[id];
                            final isAi = _records.any(
                              (e) => e.workId == id && e.isAi,
                            );
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
                                                    ? '正在统计文件 · ${records.length} 个目录'
                                                    : '$fileCount 个歌词/字幕文件 · ${records.length} 个目录',
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
                                        if (isAi)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: p.accent.withValues(
                                                alpha: .14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              'AI',
                                              style: TextStyle(
                                                color: p.accent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
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
