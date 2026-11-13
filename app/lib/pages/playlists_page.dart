import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../smooth_scroll.dart';
import '../theme.dart';
import '../l10n/strings.dart';

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
          appBar: AppBar(
            title: Text(context.l10n.morePageBuildRow),
            leading: const BackButton(),
          ),
          floatingActionButton: app.sfwMode
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _createPlaylist(context),
                  backgroundColor: p.accent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(
                    context.l10n.playlistsPageBuildText2,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
          body: app.sfwMode
              ? Center(
                  child: Text(
                    context.l10n.playlistsPageBuildText4,
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : app.playlists.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.playlistsPageBuildText5,
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : SmoothListView.separated(
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
                                    context.l10n.playlistsPageBuildText7(
                                      (entries.length).toString(),
                                    ),
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
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(
                                    context.l10n.playlistsPageBuildText,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(context.l10n.delete),
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
    final l10n = context.l10n;
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.playlistsPageBuildText2),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: InputDecoration(
            hintText: l10n.playlistsPageNameHintText,
            hintStyle: TextStyle(fontSize: 13, color: p.dim),
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.playlistsPageNameText),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      app.createPlaylist(name);
    }
  }

  Future<void> _renamePlaylist(BuildContext context, String oldName) async {
    final l10n = context.l10n;
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final ctrl = TextEditingController(text: oldName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.playlistsPageNameText2),
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
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.save),
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
    // 列表里没有该作品时，从 RJ 号还原数字 id，保证详情页仍能加载
    // 曲目、封面和评分（否则 WorkPage 会一直停留在骨架屏）。
    final isDlsite = entry.tracks.any(
      (track) => track.url?.startsWith('dlsite-play:') == true,
    );
    final id = isDlsite == app.isDlsite
        ? ApiService.apiIdForWork(app, entry.rj)
        : null;
    final base = ApiService.resolveBase(app).replaceFirst(RegExp(r'/+$'), '');
    return Work(
      rj: entry.rj,
      title: entry.title,
      circle: entry.circle,
      va: '',
      age: entry.age ?? Age.all,
      ageKnown: entry.age != null,
      dur: '',
      tags: const [],
      grad: 0,
      apiId: id,
      coverUrl: id == null || app.isDlsite ? null : '$base/api/cover/$id',
    );
  }

  void _playTrack(
    BuildContext context,
    List<PlaylistEntry> entries,
    PlaylistEntry entry,
    PlaylistTrack track,
  ) {
    if (track.url == null || track.url!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.playlistsPagePlayTrackText2)),
      );
      return;
    }
    final work = _workFor(entry);
    app.rememberPlaylistAge(work);
    final files = <MediaNode>[];
    var index = -1;
    for (final currentEntry in entries) {
      final owner = identical(currentEntry, entry)
          ? work
          : _workFor(currentEntry);
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
            work: owner,
          ),
        );
      }
    }
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.playlistsPagePlayTrackText)),
      );
      return;
    }
    app.startPlayback(work, files, initialTrackIndex: index < 0 ? 0 : index);
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
        // 桌面端没有"长按"习惯，改用按下即可拖动；移动端保持长按拖动。
        final isDesktop = const {
          TargetPlatform.windows,
          TargetPlatform.linux,
          TargetPlatform.macOS,
        }.contains(Theme.of(context).platform);
        return Scaffold(
          appBar: AppBar(title: Text(name), leading: const BackButton()),
          body: entries.isEmpty
              ? Center(
                  child: Text(
                    hiddenBySfw
                        ? context.l10n.playlistsPageBuildText6
                        : context.l10n.playlistsPageBuildText3,
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          Icon(Icons.drag_indicator, size: 15, color: p.dim),
                          const SizedBox(width: 4),
                          Text(
                            isDesktop
                                ? context.l10n.playlistsPageBuildText8
                                : context.l10n.playlistsPageBuildText9,
                            style: TextStyle(fontSize: 11.5, color: p.dim),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SmoothCustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                            sliver: SliverReorderableList(
                              itemCount: entries.length,
                              // 每个条目自己挂拖动监听（桌面直接拖、移动端长按拖），
                              // SliverReorderableList 不生成默认拖动手柄。
                              proxyDecorator: (child, index, animation) =>
                                  Material(
                                    elevation: 6,
                                    color: p.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    child: child,
                                  ),
                              onReorderItem: (oldIndex, newIndex) =>
                                  app.reorderPlaylist(name, oldIndex, newIndex),
                              itemBuilder: (ctx, i) {
                                final e = entries[i];
                                final work = _workFor(e);
                                // 只有标题行可以拖动，用来调整作品之间的顺序。
                                final header = Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: e.rj.isEmpty
                                            ? null
                                            : () => Navigator.of(
                                                ctx,
                                              ).push(buildWorkRoute(app, work)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            if (e.title.isNotEmpty &&
                                                e.title != e.rj)
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
                                      context.l10n.playlistsPageHeaderText(
                                        (e.tracks.length).toString(),
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: p.dim,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: context
                                          .l10n
                                          .playlistsPageHeaderMessage,
                                      child: Icon(
                                        Icons.drag_indicator,
                                        size: 17,
                                        color: p.dim,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          app.removeFromPlaylist(name, i),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: p.dim,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: context
                                          .l10n
                                          .playlistsPageHeaderTooltip,
                                    ),
                                  ],
                                );
                                final headerDrag = isDesktop
                                    ? ReorderableDragStartListener(
                                        index: i,
                                        child: header,
                                      )
                                    : ReorderableDelayedDragStartListener(
                                        index: i,
                                        child: header,
                                      );
                                return Column(
                                  key: ObjectKey(e),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    headerDrag,
                                    const SizedBox(height: 4),
                                    // 媒体行各自可拖动，调整作品内音频的播放顺序。
                                    ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: e.tracks.length,
                                      buildDefaultDragHandles: false,
                                      onReorderItem: (oldIndex, newIndex) =>
                                          app.reorderPlaylistTrack(
                                            name,
                                            i,
                                            oldIndex,
                                            newIndex,
                                          ),
                                      itemBuilder: (ctx, j) {
                                        final track = e.tracks[j];
                                        final row = InkWell(
                                          onTap: () => _playTrack(
                                            ctx,
                                            entries,
                                            e,
                                            track,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              8,
                                              4,
                                              8,
                                            ),
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
                                                    track.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: p.text,
                                                    ),
                                                  ),
                                                ),
                                                if (track.url == null)
                                                  Icon(
                                                    Icons.cloud_off_outlined,
                                                    size: 15,
                                                    color: p.dim,
                                                  ),
                                                const SizedBox(width: 4),
                                                Tooltip(
                                                  message: context
                                                      .l10n
                                                      .playlistsPageRowMessage,
                                                  child: Icon(
                                                    Icons.drag_indicator,
                                                    size: 15,
                                                    color: p.dim,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        return isDesktop
                                            ? ReorderableDragStartListener(
                                                key: ObjectKey(track),
                                                index: j,
                                                child: row,
                                              )
                                            : ReorderableDelayedDragStartListener(
                                                key: ObjectKey(track),
                                                index: j,
                                                child: row,
                                              );
                                      },
                                    ),
                                    if (i != entries.length - 1)
                                      Divider(height: 18, color: p.line),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
