import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../services/api_service.dart';
import '../smooth_scroll.dart';
import '../theme.dart';
import '../widgets.dart';
import '../l10n/strings.dart';

/// 歌单选择结果：`playlist == null` 表示选中了「我的收藏」。
class PlaylistPick {
  final PlaylistInfo? playlist;
  const PlaylistPick(this.playlist);
}

/// 打开收藏页的歌单切换面板。
Future<PlaylistPick?> showPlaylistPicker(
  BuildContext context, {
  required AppState app,
  bool reviewsMode = false,
  String? currentId,
}) => _showPlaylistSheet(
  context,
  app: app,
  reviewsMode: reviewsMode,
  currentId: currentId,
);

Future<void> showWorkPlaylistMembership(
  BuildContext context, {
  required AppState app,
  required Work work,
}) async {
  await _showPlaylistSheet(context, app: app, work: work);
}

Future<PlaylistPick?> _showPlaylistSheet(
  BuildContext context, {
  required AppState app,
  bool reviewsMode = false,
  String? currentId,
  Work? work,
}) {
  return showModalBottomSheet<PlaylistPick>(
    context: context,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark.surface
        : AppColors.light.surface,
    isScrollControlled: true,
    enableDrag: work == null,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlaylistPickerSheet(
      app: app,
      reviewsMode: reviewsMode,
      currentId: currentId,
      work: work,
    ),
  );
}

/// 创建/编辑播放列表对话框的返回值。
class _PlaylistEditInput {
  final String? name;
  final String description;
  final int privacy;
  final bool delete;

  const _PlaylistEditInput.save({
    required this.name,
    required this.description,
    required this.privacy,
  }) : delete = false;

  const _PlaylistEditInput.delete()
    : name = null,
      description = '',
      privacy = 0,
      delete = true;
}

class _PlaylistPickerSheet extends StatefulWidget {
  final AppState app;
  final bool reviewsMode;
  final String? currentId;
  final Work? work;

  const _PlaylistPickerSheet({
    required this.app,
    required this.reviewsMode,
    this.currentId,
    this.work,
  });

  @override
  State<_PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends State<_PlaylistPickerSheet> {
  List<PlaylistInfo> _list = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final Map<String, bool> _membership = {};
  final Map<String, bool> _changes = {};
  bool _saveFailed = false;
  late final int _serverEpoch;
  late final int _loginEpoch;
  late final int _dlsiteEpoch;
  late final String _base;
  late final String _user;

  AppState get app => widget.app;
  bool get _editingMembership => widget.work != null;
  bool get _sameSource =>
      app.serverEpoch == _serverEpoch &&
      app.loginEpoch == _loginEpoch &&
      app.dlsiteSessionEpoch == _dlsiteEpoch &&
      ApiService.resolveBase(app) == _base &&
      _playlistUser == _user;
  String get _playlistUser => app.customServer && app.customSites.isNotEmpty
      ? app.customSites[app.customServerIdx].user
      : app.isDlsite
      ? ''
      : app.asmrUser;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _serverEpoch = app.serverEpoch;
    _loginEpoch = app.loginEpoch;
    _dlsiteEpoch = app.dlsiteSessionEpoch;
    _base = ApiService.resolveBase(app);
    _user = _playlistUser;
    if (_editingMembership) app.addListener(_onSourceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (!_editingMembership || _sameSource)) _load();
    });
  }

  @override
  void dispose() {
    if (_editingMembership) app.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    if (_sameSource) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _canUseSource() {
    if (!mounted) return false;
    if (_sameSource) return true;
    _onSourceChanged();
    return false;
  }

  static bool _isEditable(PlaylistInfo playlist) =>
      playlist.id.isNotEmpty && playlist.isOwned && !playlist.isSystem;

  Future<void> _load() async {
    final l10n = context.l10n;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var list = await ApiService.fetchPlaylists(app);
      if (!mounted || (_editingMembership && !_canUseSource())) return;
      final work = widget.work;
      if (work != null) {
        list = list.where(_isEditable).toList();
        setState(() => _list = list);
        final membership = await ApiService.fetchWorkPlaylistMembership(
          app,
          work,
          list,
        );
        if (!_canUseSource()) return;
        _membership
          ..clear()
          ..addAll(membership);
        final ids = list.map((playlist) => playlist.id).toSet();
        _changes.removeWhere(
          (id, value) => !ids.contains(id) || membership[id] == value,
        );
        if (_changes.isEmpty) _saveFailed = false;
      }
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || (_editingMembership && !_canUseSource())) return;
      setState(() {
        _loading = false;
        _error = l10n.playlistPickerLoadSetState;
      });
    }
  }

  void _toggleMembership(String id) {
    final current = _membership[id];
    if (current == null || !_canUseSource()) return;
    setState(() {
      if (_changes.containsKey(id)) {
        _changes.remove(id);
      } else {
        _changes[id] = !current;
      }
      if (_changes.isEmpty) _saveFailed = false;
    });
  }

  Future<void> _saveMembership() async {
    final work = widget.work!;
    final workId = work.apiId;
    if (workId == null || !_canUseSource()) return;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    var changed = false;
    for (final MapEntry(:key, :value) in _changes.entries.toList()) {
      try {
        if (value) {
          await ApiService.addWorksToPlaylist(app, key, [work.rj]);
        } else {
          await ApiService.removeWorksFromPlaylist(app, key, [
            workId.toString(),
          ]);
        }
        if (!_canUseSource()) return;
        _membership[key] = value;
        _changes.remove(key);
        changed = true;
      } catch (_) {
        if (!_canUseSource()) return;
      }
    }
    if (_changes.isNotEmpty) {
      // A failed response can arrive after the server has applied the change.
      final pending = _list.where((pl) => _changes.containsKey(pl.id)).toList();
      final actual = await ApiService.fetchWorkPlaylistMembership(
        app,
        work,
        pending,
      );
      if (!_canUseSource()) return;
      for (final MapEntry(:key, :value) in actual.entries) {
        if (_changes[key] == value) {
          _membership[key] = value;
          _changes.remove(key);
          changed = true;
        }
      }
    }
    if (changed) app.notifyPlaylistContentsChanged();
    if (!mounted) return;
    if (_changes.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final list = await ApiService.fetchPlaylists(app);
      if (!mounted) return;
      setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyLink(PlaylistInfo pl) {
    Clipboard.setData(ClipboardData(text: ApiService.playlistShareLink(pl.id)));
    _toast(context.l10n.shareLinkCopied);
  }

  Future<void> _showDetails(PlaylistInfo pl) async {
    final l10n = context.l10n;
    var info = pl;
    try {
      info = await ApiService.fetchPlaylistMetadata(app, pl.id);
    } catch (_) {
      // 详情接口不可用时退回列表里的信息。
    }
    if (!mounted) return;
    final rows = <MapEntry<String, String>>[
      MapEntry('UUID', info.id),
      MapEntry(l10n.name, info.name),
      MapEntry(
        l10n.description,
        info.description.isEmpty ? ' ' : info.description,
      ),
      MapEntry(l10n.playlistPickerRowsMapEntry2, info.userName),
      MapEntry(
        l10n.playlistPickerRowsMapEntry,
        ApiService.playlistPrivacyLabel(info.privacy),
      ),
      MapEntry(l10n.language, info.locale.isEmpty ? ' ' : info.locale),
      MapEntry(l10n.playlistPickerRowsMapEntry4, '${info.playbackCount}'),
      MapEntry(l10n.playlistPickerRowsMapEntry6, info.createdAt),
      MapEntry(l10n.playlistPickerRowsMapEntry3, info.updatedAt),
      MapEntry(l10n.playlistPickerRowsMapEntry5, '${info.worksCount}'),
    ];
    final copy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.playlistPickerCopyText),
        content: SizedBox(
          width: 420,
          child: SmoothSingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 68,
                          child: Text(
                            row.key,
                            style: TextStyle(fontSize: 12, color: p.dim),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            row.value,
                            style: TextStyle(fontSize: 12.5, color: p.text),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.playlistPickerCopyText2),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    );
    if (copy == true) _copyLink(info);
  }

  Future<_PlaylistEditInput?> _showEditor(PlaylistInfo? playlist) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: playlist?.name ?? '');
    final descCtrl = TextEditingController(text: playlist?.description ?? '');
    var privacy = playlist?.privacy ?? 0;
    return showDialog<_PlaylistEditInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: p.surface,
          title: Text(
            playlist == null
                ? l10n.playlistPickerShowEditorText
                : l10n.playlistPickerPlaylistItemTooltip2,
          ),
          content: SizedBox(
            width: 420,
            child: SmoothSingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    maxLength: 100,
                    style: TextStyle(fontSize: 13, color: p.text),
                    decoration: InputDecoration(
                      labelText: l10n.name,
                      filled: true,
                      fillColor: p.surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    style: TextStyle(fontSize: 13, color: p.text),
                    decoration: InputDecoration(
                      labelText: l10n.description,
                      filled: true,
                      fillColor: p.surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: privacy,
                    decoration: InputDecoration(
                      labelText: l10n.playlistPickerShowEditorLabelText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    items: [
                      for (final entry
                          in ApiService.playlistPrivacyLabels.entries)
                        DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => privacy = value ?? 0),
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (playlist != null && !playlist.isSystem)
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, const _PlaylistEditInput.delete()),
                child: Text(
                  l10n.delete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              )
            else
              const SizedBox.shrink(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      ctx,
                      _PlaylistEditInput.save(
                        name: name,
                        description: descCtrl.text.trim(),
                        privacy: privacy,
                      ),
                    );
                  },
                  child: Text(l10n.confirmAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final l10n = context.l10n;
    if (_busy) return;
    final input = await _showEditor(null);
    if (!mounted || (_editingMembership && !_canUseSource()) || input == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final beforeIds = _list.map((e) => e.id).toSet();
      final name = input.name ?? l10n.apiServiceMapPlaylistName;
      await ApiService.createPlaylist(
        app,
        name: name,
        description: input.description,
        privacy: input.privacy,
      );
      if (_editingMembership) {
        if (!_canUseSource()) return;
        await _load();
        if (!_canUseSource()) return;
        final matches = _list.where(
          (pl) => !beforeIds.contains(pl.id) && pl.name == name,
        );
        setState(() {
          _busy = false;
          if (matches.length == 1 && _membership[matches.first.id] == false) {
            _changes[matches.first.id] = true;
          }
        });
        return;
      }
      final list = await ApiService.fetchPlaylists(app);
      if (!mounted) return;
      PlaylistInfo? created;
      for (final pl in list) {
        if (!beforeIds.contains(pl.id)) {
          created = pl;
          break;
        }
      }
      if (created == null || created.id.isEmpty) {
        setState(() {
          _list = list;
          _busy = false;
        });
        _toast(l10n.playlistPickerCreatePlaylistToast2);
        return;
      }
      Navigator.of(context).pop(PlaylistPick(created));
    } catch (e) {
      if (!mounted || (_editingMembership && !_canUseSource())) return;
      setState(() => _busy = false);
      _toast(l10n.playlistPickerCreatePlaylistToast((e).toString()));
    }
  }

  Future<void> _editPlaylist(PlaylistInfo pl) async {
    final l10n = context.l10n;
    if (_busy) return;
    final input = await _showEditor(pl);
    if (input == null || !mounted) return;
    if (input.delete) {
      await _deletePlaylist(pl);
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.editPlaylist(
        app,
        id: pl.id,
        name: input.name ?? pl.name,
        description: input.description,
        privacy: input.privacy,
      );
      final updated = await ApiService.fetchPlaylistMetadata(app, pl.id);
      if (!mounted) return;
      if (widget.currentId == pl.id) {
        Navigator.of(context).pop(PlaylistPick(updated));
        return;
      }
      setState(() => _busy = false);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.workPageSubmitNotify((e).toString()));
    }
  }

  Future<void> _deletePlaylist(PlaylistInfo pl) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.playlistPickerOkText),
        content: Text(l10n.playlistPickerOkText2((pl.name).toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.deletePlaylist(app, pl.id);
      if (!mounted) return;
      if (widget.currentId == pl.id) {
        Navigator.of(context).pop(const PlaylistPick(null));
        return;
      }
      setState(() => _busy = false);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.workPageDeleteNotify((e).toString()));
    }
  }

  Future<void> _removeLiked(PlaylistInfo pl) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.playlistPickerPlaylistItemTooltip),
        content: Text(l10n.playlistPickerOkText3((pl.name).toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.removeLikedPlaylist(app, pl.id);
      if (!mounted) return;
      if (widget.currentId == pl.id) {
        Navigator.of(context).pop(const PlaylistPick(null));
        return;
      }
      setState(() => _busy = false);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.playlistPickerRemoveLikedToast((e).toString()));
    }
  }

  Future<void> _importPlaylist() async {
    final l10n = context.l10n;
    if (_busy) return;
    final ctrl = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.playlistPickerLinkText),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: p.text),
              decoration: InputDecoration(
                labelText: l10n.playlistPickerLinkLabelText,
                hintText: 'https://www.asmr.one/playlist/…',
                filled: true,
                fillColor: p.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.playlistPickerLinkText2,
              style: TextStyle(fontSize: 11.5, color: p.dim),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(l10n.importAction),
          ),
        ],
      ),
    );
    if (link == null || !mounted) return;
    final id = ApiService.playlistIdFromLink(link);
    if (id == null) {
      _toast(l10n.playlistPickerImportPlaylistToast);
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.importPlaylist(app, id);
      final list = await ApiService.fetchPlaylists(app);
      if (!mounted) return;
      PlaylistInfo? imported;
      for (final pl in list) {
        if (pl.id == id) {
          imported = pl;
          break;
        }
      }
      if (imported == null) {
        setState(() {
          _list = list;
          _busy = false;
        });
        _toast(l10n.playlistPickerImportPlaylistToast2);
        return;
      }
      Navigator.of(context).pop(PlaylistPick(imported));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.lyricsLibraryPageImportText5((e).toString()));
    }
  }

  Widget _leading({required String? coverUrl, required IconData icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: coverUrl != null
            ? Image(
                image: ResizeImage.resizeIfNeeded(
                  128,
                  null,
                  RustImageProvider(coverUrl),
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _iconBox(icon),
              )
            : _iconBox(icon),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      color: p.surface2,
      child: Icon(icon, size: 18, color: p.accent),
    );
  }

  Widget _row({
    required Widget leading,
    required String name,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
    Widget? trailing,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      onLongPress: _busy ? null : onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            leading,
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
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.dim),
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle, size: 18, color: p.accent),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _reviewsItem() {
    return _row(
      leading: _iconBox(Icons.favorite),
      name: context.l10n.playlistPickerReviewsItemName,
      subtitle: context.l10n.playlistPickerReviewsItemSubtitle,
      selected: widget.reviewsMode,
      onTap: () => Navigator.of(context).pop(const PlaylistPick(null)),
    );
  }

  Widget _playlistItem(PlaylistInfo pl) {
    final l10n = context.l10n;
    final subtitle = pl.description.isNotEmpty
        ? l10n.playlistPickerSubtitleSubtitle2(
            (pl.worksCount).toString(),
            (pl.description.replaceAll('\n', ' ')).toString(),
          )
        : l10n.playlistPickerSubtitleSubtitle((pl.worksCount).toString());
    final leading = _leading(
      coverUrl: pl.coverUrl,
      icon: Icons.folder_outlined,
    );
    if (_editingMembership) {
      final current = _membership[pl.id];
      final value = current == null ? null : _changes[pl.id] ?? current;
      final canToggle = !_loading && !_busy && current != null;
      void toggle() => _toggleMembership(pl.id);
      return _row(
        leading: leading,
        name: pl.name,
        subtitle: !_loading && value == null
            ? l10n.workPlaylistMembershipUnknown
            : subtitle,
        selected: false,
        onTap: canToggle ? toggle : null,
        trailing: Checkbox(
          value: value,
          tristate: value == null,
          semanticLabel: pl.name,
          onChanged: canToggle ? (_) => toggle() : null,
        ),
      );
    }
    return _row(
      leading: leading,
      name: pl.name,
      subtitle: subtitle,
      selected: !widget.reviewsMode && pl.id == widget.currentId,
      onTap: () => Navigator.of(context).pop(PlaylistPick(pl)),
      onLongPress: app.isDlsite || pl.isSystem ? null : () => _showDetails(pl),
      trailing: pl.isSystem
          ? null
          : pl.isOwned
          ? IconButton(
              onPressed: _busy ? null : () => _editPlaylist(pl),
              tooltip: context.l10n.playlistPickerPlaylistItemTooltip2,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.edit_outlined, size: 18, color: p.dim),
            )
          : IconButton(
              onPressed: _busy ? null : () => _removeLiked(pl),
              tooltip: context.l10n.playlistPickerPlaylistItemTooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, size: 18, color: p.dim),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_editingMembership || !_busy,
      child: _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final l10n = context.l10n;
    final canSave =
        !_busy &&
        !_loading &&
        _error == null &&
        _changes.isNotEmpty &&
        _changes.keys.every(_membership.containsKey);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            if (!_editingMembership)
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.surface3,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editingMembership
                          ? l10n.workPlaylistMembershipTitle
                          : l10n.playlistPickerBuildText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy || (_editingMembership && _loading)
                        ? null
                        : _createPlaylist,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      context.l10n.create,
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (!_editingMembership && !app.isDlsite)
                    TextButton.icon(
                      onPressed: _busy ? null : _importPlaylist,
                      icon: const Icon(Icons.link, size: 18),
                      label: Text(
                        context.l10n.importAction,
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading && _list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(_error!, style: TextStyle(fontSize: 13, color: p.dim)),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              )
            else if (_editingMembership && _list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.workPlaylistMembershipEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.dim),
                ),
              )
            else
              Flexible(
                child: SmoothListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    if (!_editingMembership) ...[
                      _reviewsItem(),
                      const Divider(height: 1),
                    ],
                    for (final pl in _list) _playlistItem(pl),
                  ],
                ),
              ),
            if (_editingMembership) ...[
              if ((_loading && _list.isNotEmpty) || _busy)
                const LinearProgressIndicator(),
              if (_saveFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    l10n.workPlaylistMembershipSaveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    if (!_loading &&
                        _error == null &&
                        _list.any((pl) => !_membership.containsKey(pl.id)))
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: Text(l10n.retry),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: canSave ? _saveMembership : null,
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              ),
            ] else if (_busy)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
