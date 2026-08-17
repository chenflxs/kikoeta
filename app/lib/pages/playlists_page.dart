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
      appBar: AppBar(title: const Text('播放列表'), leading: const BackButton()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createPlaylist(context),
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('新建播放列表', style: TextStyle(fontSize: 13)),
      ),
      body: app.playlists.isEmpty
          ? Center(
              child: Text(
                '暂无播放列表，点击右下角新建',
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
                      builder: (_) => PlaylistDetailPage(app: app, name: name),
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
                                style: TextStyle(fontSize: 11, color: p.dim),
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
                            PopupMenuItem(value: 'rename', child: Text('重命名')),
                            PopupMenuItem(value: 'delete', child: Text('删除')),
                          ],
                          icon: Icon(Icons.more_vert, size: 18, color: p.dim),
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
        title: const Text('新建播放列表'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: InputDecoration(
            hintText: '播放列表名称',
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
        title: const Text('重命名播放列表'),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        final entries = app.playlists[name] ?? const [];
        return Scaffold(
      appBar: AppBar(title: Text(name), leading: const BackButton()),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '播放列表为空',
                style: TextStyle(fontSize: 13, color: p.dim),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final e = entries[i];
                return Container(
                  padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Work? w;
                            for (final x in app.remoteWorks) {
                              if (x.rj == e.rj) {
                                w = x;
                                break;
                              }
                            }
                            if (w == null) return;
                            Navigator.of(ctx).push(buildWorkRoute(app, w));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.rj.isEmpty
                                    ? (e.tracks.isEmpty
                                          ? '未知作品'
                                          : '${e.tracks.length} 个曲目')
                                    : '${e.rj} · ${e.circle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: p.dim),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => app.removeFromPlaylist(name, i),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: p.dim,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              },
            ),
        );
      },
    );
  }
}
