import 'dart:io';

import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../services/download_service.dart';
import '../theme.dart';
import '../widgets.dart';

class DownloadPage extends StatefulWidget {
  final AppState app;
  const DownloadPage({super.key, required this.app});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  static const _batchSize = 50;
  bool _selecting = false;
  bool _searching = false;
  int _visibleCount = _batchSize;
  final Set<String> _selected = {};
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  AppState get app => widget.app;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelection() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    await DownloadManager.instance.deleteWorks(Set.of(_selected));
    _exitSelection();
  }

  void _selectAll(List<VoiceDownload> items) {
    setState(() {
      if (_selected.length == items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(items.map((item) => item.id));
      }
    });
  }

  void _loadMore(int total) {
    setState(() {
      _visibleCount = (_visibleCount + _batchSize).clamp(0, total).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final allItems = DownloadManager.instance.downloads;
        final query = _search.text.trim().toLowerCase();
        final items = query.isEmpty
            ? allItems
            : allItems
                  .where(
                    (item) =>
                        item.work.rj.toLowerCase().contains(query) ||
                        item.work.title.toLowerCase().contains(query),
                  )
                  .toList();
        final visibleItems = items.take(_visibleCount).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('下载'),
            leading: _selecting
                ? IconButton(
                    tooltip: '退出多选',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _exitSelection,
                  )
                : const BackButton(),
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
                  tooltip: '搜索已下载作品',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _searching = true),
                ),
              if (_selecting) ...[
                IconButton(
                  tooltip: '删除选中作品',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
                IconButton(
                  tooltip: _selected.length == allItems.length ? '取消全选' : '全选',
                  icon: Icon(
                    _selected.length == allItems.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: () => _selectAll(allItems),
                ),
              ],
              IconButton(
                tooltip: _selecting ? '退出多选' : '多选',
                icon: Icon(_selecting ? Icons.close : Icons.checklist_outlined),
                onPressed: _toggleSelection,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              if (_searching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _downloadSearchField(),
                ),
              _DownloadProgressBanner(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DownloadFilesPage(app: app),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('暂无下载音声')),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 210).floor().clamp(
                      2,
                      8,
                    );
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 13,
                        mainAxisSpacing: 16,
                        childAspectRatio: .68,
                      ),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return _VoiceCard(
                          item: item,
                          selecting: _selecting,
                          selected: _selected.contains(item.id),
                          onSelect: () => setState(() {
                            if (!_selected.add(item.id)) {
                              _selected.remove(item.id);
                            }
                          }),
                          onTap: () => _selecting
                              ? setState(() {
                                  if (!_selected.add(item.id)) {
                                    _selected.remove(item.id);
                                  }
                                })
                              : Navigator.of(context).push(
                                  buildWorkRoute(
                                    app,
                                    item.work,
                                    downloadItem: item,
                                  ),
                                ),
                        );
                      },
                    );
                  },
                ),
              if (visibleItems.length < items.length)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => _loadMore(items.length),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: Text(
                        '加载更多（${items.length - visibleItems.length}）',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _downloadSearchField() {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
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
                hintText: '搜索已下载作品',
                hintStyle: TextStyle(fontSize: 14, color: p.dim),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (_) => setState(() => _visibleCount = _batchSize),
            ),
          ),
          if (_search.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                setState(() {});
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

class _DownloadProgressBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DownloadProgressBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final item = manager.activeDownload;
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final progress = item == null ? 0.0 : manager.activeProgress;
    final percent = item == null || item.currentFileTotal <= 0
        ? '--'
        : '${(progress * 100).round()}%';
    final fileName = item?.currentPath?.split('/').last ?? '暂无正在下载的文件';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_outlined, size: 16, color: p.accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(percent, style: TextStyle(fontSize: 12, color: p.accent)),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: item == null || item.currentFileTotal <= 0
                    ? 0
                    : progress,
                minHeight: 8,
                backgroundColor: p.surface3,
                color: p.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final VoiceDownload item;
  final bool selecting;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onTap;
  const _VoiceCard({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final status = switch (item.status) {
      VoiceDownloadStatus.completed => '已完成',
      VoiceDownloadStatus.downloading => _progressText(item),
      VoiceDownloadStatus.queued => '等待下载',
      VoiceDownloadStatus.paused => '已暂停',
      VoiceDownloadStatus.failed => '下载失败',
    };
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              WorkCard(
                work: item.work,
                index: 0,
                showBadges: true,
                onTap: onTap,
              ),
              if (selecting)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onSelect(),
                      activeColor: p.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                item.status == VoiceDownloadStatus.failed
                    ? Icons.error_outline
                    : Icons.download_done_outlined,
                size: 14,
                color: item.status == VoiceDownloadStatus.failed
                    ? p.red
                    : p.accent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: p.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _progressText(VoiceDownload item) {
  if (item.totalBytes <= 0) return '下载中';
  final percent = (item.downloadedBytes * 100 / item.totalBytes)
      .clamp(0, 100)
      .toStringAsFixed(0);
  return '下载中 $percent%';
}

class DownloadFilesPage extends StatefulWidget {
  final AppState app;
  const DownloadFilesPage({super.key, required this.app});

  @override
  State<DownloadFilesPage> createState() => _DownloadFilesPageState();
}

class _DownloadFilesPageState extends State<DownloadFilesPage> {
  bool _selecting = false;
  final Set<String> _selected = {};

  AppState get app => widget.app;

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelection() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  Map<String, Set<String>> _selectedFiles() {
    final result = <String, Set<String>>{};
    for (final key in _selected) {
      for (final item in DownloadManager.instance.downloads) {
        final prefix = '${item.id}|';
        if (!key.startsWith(prefix)) continue;
        result
            .putIfAbsent(item.id, () => <String>{})
            .add(key.substring(prefix.length));
        break;
      }
    }
    return result;
  }

  String _fileKey(VoiceDownload item, MediaNode node) =>
      '${item.id}|${node.path}';

  Set<String> _fileKeys(VoiceDownload item, Iterable<MediaNode> files) =>
      files.map((node) => _fileKey(item, node)).toSet();

  void _toggleItemSelection(VoiceDownload item, List<MediaNode> files) {
    final keys = _fileKeys(item, files);
    if (keys.isEmpty) return;
    setState(() {
      final fullySelected = keys.every(_selected.contains);
      if (fullySelected) {
        _selected.removeAll(keys);
      } else {
        _selected.addAll(keys);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    await DownloadManager.instance.removeFileRecords(_selectedFiles());
    _exitSelection();
  }

  void _selectAll(List<VoiceDownload> items) {
    final all = <String>{};
    for (final item in items) {
      for (final node in DownloadManager.instance.selectedFiles(item)) {
        all.add(_fileKey(item, node));
      }
    }
    setState(() {
      if (_selected.length == all.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(all);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final manager = DownloadManager.instance;
        final items = manager.recordItems;
        final allFiles = <String>{};
        for (final item in items) {
          for (final node in manager.selectedFiles(item)) {
            allFiles.add(_fileKey(item, node));
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('下载文件'),
            leading: _selecting
                ? IconButton(
                    tooltip: '退出多选',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _exitSelection,
                  )
                : const BackButton(),
            actions: [
              IconButton(
                tooltip: '开始/暂停全部',
                icon: Icon(
                  items.any(
                        (item) =>
                            item.status == VoiceDownloadStatus.downloading ||
                            item.status == VoiceDownloadStatus.queued,
                      )
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                onPressed: items.isEmpty ? null : manager.toggleAll,
              ),
              if (_selecting) ...[
                IconButton(
                  tooltip: '删除选中下载记录',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
                IconButton(
                  tooltip: _selected.length == allFiles.length ? '取消全选' : '全选',
                  icon: Icon(
                    _selected.length == allFiles.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: () => _selectAll(items),
                ),
              ],
              IconButton(
                tooltip: _selecting ? '退出多选' : '多选',
                icon: Icon(_selecting ? Icons.close : Icons.checklist_outlined),
                onPressed: _toggleSelection,
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('暂无下载文件'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final files = manager.selectedFiles(item);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CoverArt(
                                work: item.work,
                                radius: 8,
                                showBadges: false,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.work.rj,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.work.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selecting)
                              Checkbox(
                                value: _titleSelectionState(item, files),
                                tristate: true,
                                onChanged: (_) =>
                                    _toggleItemSelection(item, files),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...files.map(
                          (node) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _DownloadFileRow(
                              item: item,
                              node: node,
                              selecting: _selecting,
                              selected: _selected.contains(
                                _fileKey(item, node),
                              ),
                              onSelect: () => setState(() {
                                final key = _fileKey(item, node);
                                if (!_selected.add(key)) _selected.remove(key);
                              }),
                              onTap: () => _openFile(context, item, node),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  bool? _titleSelectionState(VoiceDownload item, List<MediaNode> files) {
    final keys = _fileKeys(item, files);
    if (keys.isEmpty || keys.every(_selected.contains)) return true;
    if (keys.any(_selected.contains)) return null;
    return false;
  }

  void _openFile(BuildContext context, VoiceDownload item, MediaNode node) {
    final path = DownloadManager.instance.localPath(item, node);
    if (!File(path).existsSync()) return;
    Navigator.of(
      context,
    ).push(buildWorkRoute(app, item.work, downloadItem: item));
  }
}

class _DownloadFileRow extends StatelessWidget {
  final VoiceDownload item;
  final MediaNode node;
  final bool selecting;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onTap;
  const _DownloadFileRow({
    required this.item,
    required this.node,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final done = manager.isDownloaded(item, node);
    final active =
        item.currentPath == node.path &&
        item.status == VoiceDownloadStatus.downloading;
    final status = done
        ? '已完成'
        : active
        ? item.currentFileTotal > 0
              ? '下载中 ${(item.currentFileDownloaded * 100 / item.currentFileTotal).round()}%'
              : '下载中'
        : item.pausedPaths.contains(node.path)
        ? '已暂停'
        : item.status == VoiceDownloadStatus.failed
        ? '下载失败'
        : '等待中';
    return InkWell(
      onTap: selecting
          ? onSelect
          : done
          ? onTap
          : () => manager.toggleFile(item, node),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_outline : Icons.download_outlined,
              size: 18,
              color: done ? p.green : p.accent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                node.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: done ? p.text : p.dim),
              ),
            ),
            if (selecting)
              Checkbox(
                value: selected,
                onChanged: (_) => onSelect(),
                activeColor: p.accent,
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 11,
                color: item.status == VoiceDownloadStatus.failed
                    ? p.red
                    : done
                    ? p.green
                    : p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceDetailPage extends StatefulWidget {
  final AppState app;
  final VoiceDownload item;
  const VoiceDetailPage({super.key, required this.app, required this.item});

  @override
  State<VoiceDetailPage> createState() => _VoiceDetailPageState();
}

class _VoiceDetailPageState extends State<VoiceDetailPage> {
  final Set<String> _expanded = {};

  AppState get app => widget.app;
  VoiceDownload get item => widget.item;

  @override
  void initState() {
    super.initState();
    _expanded.addAll(_smartExpandedPaths(item.tree));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final p = Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        final manager = DownloadManager.instance;
        final files = manager.selectedFiles(item);
        final downloaded = files
            .where((node) => manager.isDownloaded(item, node))
            .length;
        return Scaffold(
          appBar: AppBar(
            title: Text(item.work.rj),
            leading: const BackButton(),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: CoverArt(
                      work: item.work,
                      radius: 12,
                      showBadges: false,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.work.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${item.work.rj}  $downloaded/${files.length} 个文件已下载',
                          style: TextStyle(fontSize: 11.5, color: p.muted),
                        ),
                        if (item.work.circle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.work.circle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: p.dim),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _progressText(item),
                          style: TextStyle(fontSize: 11.5, color: p.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  item.error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.red),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                '完整文件结构',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.line),
                ),
                child: Column(children: _treeRows(context, item.tree, 0)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _treeRows(
    BuildContext context,
    Iterable<MediaNode> nodes,
    int depth,
  ) {
    final manager = DownloadManager.instance;
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final rows = <Widget>[];
    for (final node in nodes) {
      final hasFile = !node.isDir && manager.isDownloaded(item, node);
      final textStyle = TextStyle(
        fontSize: 12,
        color: hasFile ? p.text : p.dim,
        decoration: node.isDir || hasFile
            ? TextDecoration.none
            : TextDecoration.lineThrough,
        decorationColor: p.dim,
      );
      if (node.isDir) {
        final open = _expanded.contains(node.path);
        rows.add(
          InkWell(
            onTap: () => setState(() {
              if (open) {
                _expanded.remove(node.path);
              } else {
                _expanded.add(node.path);
              }
            }),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10 + depth * 16, 8, 10, 8),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.folder_open_outlined : Icons.folder_outlined,
                    size: 17,
                    color: p.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(node.title, style: textStyle)),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: p.dim,
                  ),
                ],
              ),
            ),
          ),
        );
        if (open) rows.addAll(_treeRows(context, node.children, depth + 1));
      } else {
        rows.add(
          InkWell(
            onTap: hasFile && isAudioNode(node)
                ? () => _playLocal(context, node)
                : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10 + depth * 16, 8, 10, 8),
              child: Row(
                children: [
                  Icon(
                    _iconForNode(node),
                    size: 17,
                    color: hasFile ? p.green : p.dim,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(node.title, style: textStyle)),
                  Icon(
                    hasFile
                        ? Icons.check_circle_outline
                        : Icons.remove_circle_outline,
                    size: 15,
                    color: hasFile ? p.green : p.dim,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return rows;
  }

  Set<String> _smartExpandedPaths(List<MediaNode> roots) {
    final paths = <String>{};
    final manager = DownloadManager.instance;
    var current = roots;
    while (current.length == 1 && current.first.isDir) {
      paths.add(current.first.path);
      current = current.first.children;
    }
    if (current.isEmpty) return paths;

    // Download-only rule: first prefer the directory path containing the most
    // already downloaded files, so partially downloaded works open where the
    // user can immediately see local content.
    List<MediaNode>? downloadedPath;
    var downloadedCount = 0;
    void scanDownloaded(List<MediaNode> nodes, List<MediaNode> ancestors) {
      var count = 0;
      for (final node in nodes) {
        if (node.isDir) {
          scanDownloaded(node.children, [...ancestors, node]);
        } else if (manager.isDownloaded(item, node)) {
          count++;
        }
      }
      if (count > downloadedCount && ancestors.isNotEmpty) {
        downloadedCount = count;
        downloadedPath = ancestors;
      }
    }

    scanDownloaded(current, []);
    if (downloadedPath != null) {
      for (final node in downloadedPath!) {
        paths.add(node.path);
      }
      return paths;
    }

    // No local file yet: retain the normal fallback and choose the directory
    // containing the most audio, then expand only its ancestor chain.
    List<MediaNode>? best;
    var bestCount = 0;
    void scan(List<MediaNode> nodes, List<MediaNode> ancestors) {
      var count = 0;
      for (final node in nodes) {
        if (node.isDir) {
          scan(node.children, [...ancestors, node]);
        } else if (isAudioNode(node)) {
          count++;
        }
      }
      if (count > bestCount && ancestors.isNotEmpty) {
        bestCount = count;
        best = ancestors;
      }
    }

    scan(current, []);
    if (best != null) {
      for (final node in best!) {
        paths.add(node.path);
      }
    }
    return paths;
  }

  void _playLocal(BuildContext context, MediaNode node) {
    final path = DownloadManager.instance.localPath(item, node);
    if (!File(path).existsSync()) return;
    app.startPlayback(item.work, [node]);
    Navigator.of(context).pushNamed('/player');
  }
}

IconData _iconForNode(MediaNode node) {
  final name = node.title.toLowerCase();
  if (isAudioNode(node)) return Icons.music_note;
  if (RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp|avif)$').hasMatch(name)) {
    return Icons.image_outlined;
  }
  if (RegExp(r'\.(txt|lrc|srt|json|md|log|vtt)$').hasMatch(name)) {
    return Icons.description_outlined;
  }
  if (RegExp(r'\.(mp4|mkv|webm|avi|mov|wmv|flv|ts|m4v)$').hasMatch(name)) {
    return Icons.movie_outlined;
  }
  return Icons.insert_drive_file_outlined;
}
