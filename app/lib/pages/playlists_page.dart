import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../theme.dart';

class PlaylistsPage extends StatelessWidget {
  final AppState app;
  const PlaylistsPage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        return Scaffold(
          appBar: AppBar(title: const Text('歌单'), leading: const BackButton()),
          floatingActionButton: app.sfwMode
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _createPlaylist(context),
                  backgroundColor: p.accent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('新建歌单', style: TextStyle(fontSize: 13)),
                ),
          body: app.sfwMode
              ? Center(
                  child: Text(
                    'SFW 模式下不显示歌单',
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : app.playlists.isEmpty
              ? Center(
                  child: Text(
                    '暂无歌单，点击右下角新建',
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: app.playlists.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final name = app.playlists.keys.elementAt(i);
                    final entries = app.playlists[name]!;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailPage(app: app, name: name),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: p.surface2,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.queue_music,
                                size: 18,
                                color: p.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${entries.length} 个条目',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.dim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'rename') {
                                  _renamePlaylist(context, name);
                                } else if (v == 'delete') {
                                  app.deletePlaylist(name);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('重命名'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: p.dim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('新建歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: InputDecoration(
            hintText: '歌单名称',
            hintStyle: TextStyle(fontSize: 13, color: p.dim),
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      app.createPlaylist(name);
    }
  }

  Future<void> _renamePlaylist(BuildContext context, String oldName) async {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final ctrl = TextEditingController(text: oldName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('重命名歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      app.renamePlaylist(oldName, name);
    }
  }
}

class PlaylistDetailPage extends StatelessWidget {
  final AppState app;
  final String name;
  const PlaylistDetailPage({super.key, required this.app, required this.name});

  Work _workFor(PlaylistEntry entry) {
    for (final work in app.remoteWorks) {
      if (work.rj == entry.rj) return work;
    }
    return Work(
      rj: entry.rj,
      title: entry.title,
      circle: entry.circle,
      va: '',
      age: Age.all,
      dur: '',
      tags: const [],
      grad: 0,
    );
  }

  void _playTrack(
    BuildContext context,
    List<PlaylistEntry> entries,
    PlaylistEntry entry,
    PlaylistTrack track,
  ) {
    if (track.url == null || track.url!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该音频缺少可用文件流，请从作品详情重新添加')));
      return;
    }
    final files = <MediaNode>[];
    var index = -1;
    for (final currentEntry in entries) {
      for (final item in currentEntry.tracks) {
        if (item.url == null || item.url!.isEmpty) continue;
        if (identical(currentEntry, entry) && item.path == track.path) {
          index = files.length;
        }
        files.add(
          MediaNode(
            title: item.title,
            type: 'file',
            path: item.path,
            url: item.url,
            duration: item.duration,
          ),
        );
      }
    }
    if (files.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('歌单中没有可播放的音频')));
      return;
    }
    app.startPlayback(
      _workFor(entry),
      files,
      initialTrackIndex: index < 0 ? 0 : index,
    );
    Navigator.of(context).pushNamed('/player');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        final hiddenBySfw = app.sfwMode;
        final entries = hiddenBySfw
            ? const <PlaylistEntry>[]
            : app.playlists[name] ?? const [];
        return Scaffold(
          appBar: AppBar(title: Text(name), leading: const BackButton()),
          body: entries.isEmpty
              ? Center(
                  child: Text(
                    hiddenBySfw ? 'SFW 模式下不显示歌单内容' : '歌单为空',
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 18, color: p.line),
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final work = _workFor(e);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: e.rj.isEmpty
                                    ? null
                                    : () => Navigator.of(
                                        ctx,
                                      ).push(buildWorkRoute(app, work)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.rj.isEmpty ? e.title : e.rj,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (e.title.isNotEmpty && e.title != e.rj)
                                      Text(
                                        e.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: p.dim,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${e.tracks.length} 个音频',
                              style: TextStyle(fontSize: 11, color: p.dim),
                            ),
                            IconButton(
                              onPressed: () => app.removeFromPlaylist(name, i),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: p.dim,
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip: '移除作品',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...e.tracks.asMap().entries.map(
                          (item) => InkWell(
                            onTap: () =>
                                _playTrack(ctx, entries, e, item.value),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.music_note_outlined,
                                    size: 17,
                                    color: p.accent,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      item.value.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: p.text,
                                      ),
                                    ),
                                  ),
                                  if (item.value.url == null)
                                    Icon(
                                      Icons.cloud_off_outlined,
                                      size: 15,
                                      color: p.dim,
                                    ),
                                ],
                              ),
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
}
