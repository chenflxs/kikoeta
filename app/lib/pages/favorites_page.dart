import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../services/dictation_batch_importer.dart';
import '../services/dictation_queue.dart';
import '../services/lyrics_library_service.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/playlist_picker.dart';
import '../widgets/dictation_batch_import_dialog.dart';
import '../widgets/favorites_search_field.dart';
import '../l10n/strings.dart';
import 'dictation_translation_page.dart';

/// 静默比对用的作品指纹：覆盖卡片显示与收藏判定会用到的字段。
String favoritesWorkSignature(Work w) => [
  w.rj,
  w.title,
  w.circle,
  w.va,
  w.age.name,
  w.dur,
  w.releaseDate,
  w.tags.join(','),
  w.grayTags.join(','),
  jsonEncode(w.tagNames),
  w.coverUrl ?? '',
  w.hasSubtitle ? '1' : '0',
  w.apiId?.toString() ?? '',
  w.hasReview?.toString() ?? '',
].join('\u0001');

bool _matchesFavorite(Work work, Set<Age> ages, String query) =>
    (ages.isEmpty || ages.contains(work.age)) &&
    (query.isEmpty ||
        work.rj.toLowerCase().contains(query) ||
        work.title.toLowerCase().contains(query));

/// 进入收藏页时，判断后台重新拉取到的第一页是否与当前展示的数据存在差异。
///
/// - [current]：当前页面持有的列表（可能只加载了前几页）。
/// - [knownTotal]：当前列表对应的服务端总数（未知为 -1）。
/// - [fresh]：后台静默拉取到的第一页。
///
/// 收藏增删会改变服务端总数，因此总数不一致即视为有差异；总数未知时退化为
/// 逐项指纹比较已加载部分，并在服务端已到末页时比较长度。
bool favoritesListChanged(List<Work> current, int knownTotal, WorksPage fresh) {
  final list = fresh.works;
  if (fresh.totalCount >= 0 &&
      knownTotal >= 0 &&
      fresh.totalCount != knownTotal) {
    return true;
  }
  final n = list.length < current.length ? list.length : current.length;
  for (var i = 0; i < n; i++) {
    if (favoritesWorkSignature(list[i]) != favoritesWorkSignature(current[i])) {
      return true;
    }
  }
  // 服务端这一页已是末页（总数未知），长度不同即说明收藏有增删。
  if (!fresh.hasMore && fresh.totalCount < 0 && current.length != list.length) {
    return true;
  }
  return false;
}

class FavoritesPage extends StatefulWidget {
  final AppState app;
  const FavoritesPage({super.key, required this.app});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  PlaylistInfo? _playlist; // 当前歌单（null = 我的评价/收藏）
  bool _reviewsMode = true; // 默认展示「收藏」（GET /api/review）
  final List<Work> _works = [];
  final List<Work> _visibleWorks = [];
  final Set<Age> _ageFilters = {};
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _filterTimer;
  String _query = '';
  bool _searching = false;
  int _visibleTarget = 20;
  bool _loading = false;
  bool _error = false;
  bool _hasMore = true;
  int _page = 0;
  int _gen = 0;
  int _totalCount = -1; // 当前列表对应的服务端总数（未知为 -1）
  bool _silentRefreshing = false; // 进入页面时的后台比对是否在途
  String _reviewSort = 'updated_at';
  bool _reviewOrderAsc = false;
  String? _reviewFilter;
  late int _seenFavVersion;
  late int _seenFavoritesEntryVersion;
  late bool _seenSfwMode;
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _batchOpening = false;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _seenFavVersion = app.favVersion;
    _seenFavoritesEntryVersion = app.favoritesEntryVersion;
    _seenSfwMode = app.sfwMode;
    app.addListener(_onAppChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData(reset: true));
  }

  @override
  void dispose() {
    _filterTimer?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  bool get _hasViewFilter =>
      _query.isNotEmpty || (_ageFilters.isNotEmpty && _ageFilters.length < 3);

  bool _matchesWork(Work work) => _matchesFavorite(work, _ageFilters, _query);

  void _clearWorks() {
    _works.clear();
    _visibleWorks.clear();
  }

  void _appendWorks(List<Work> works) {
    _works.addAll(works);
    _visibleWorks.addAll(works.where(_matchesWork));
  }

  void _applyViewFilter() {
    _filterTimer?.cancel();
    setState(() {
      _query = _search.text.trim().toLowerCase();
      _visibleTarget = 20;
      _visibleWorks
        ..clear()
        ..addAll(_works.where(_matchesWork));
      _selected.retainAll(_visibleWorks.map((work) => work.rj));
    });
    // 输入期间复用已加载数据，停止输入后再补拉不足的一页。
    _filterTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _filterTimer = null);
      _maybeRefill();
    });
  }

  void _maybeRefill() {
    if (!mounted || app.sfwMode || _filterTimer?.isActive == true) return;
    if (_hasViewFilter &&
        !_loading &&
        !_error &&
        _hasMore &&
        _visibleWorks.length < _visibleTarget) {
      _loadData(reset: false);
    }
  }

  void _loadMore() {
    if (_loading || !_hasMore || _filterTimer?.isActive == true) return;
    _visibleTarget = _visibleWorks.length + 20;
    _loadData(reset: false);
  }

  void _onAppChanged() {
    final favoriteChanged = app.favVersion != _seenFavVersion;
    final enteredFavorites =
        app.favoritesEntryVersion != _seenFavoritesEntryVersion;
    final sfwChanged = app.sfwMode != _seenSfwMode;
    if (!favoriteChanged && !enteredFavorites && !sfwChanged) return;

    _seenFavVersion = app.favVersion;
    _seenFavoritesEntryVersion = app.favoritesEntryVersion;
    _seenSfwMode = app.sfwMode;
    if (sfwChanged && app.sfwMode) {
      // SFW 开启后立即清空当前收藏，且使在途请求结果失效。
      _gen++;
      if (mounted) {
        setState(() {
          _reviewsMode = true;
          _playlist = null;
          _selecting = false;
          _selected.clear();
          _clearWorks();
          _loading = false;
          _error = false;
          _page = 0;
          _hasMore = false;
        });
      }
      return;
    }
    if (favoriteChanged || sfwChanged) {
      // 收藏增删/开关变化需立即与服务器对齐，保持常规加载（含加载态）。
      _loadData(reset: true);
      return;
    }
    // 仅「切入收藏页」：后台拉取并比对，无差异继续用旧数据。
    _refreshOnEntry();
  }

  /// 进入收藏页时的静默刷新：后台拉取第一页并与现有数据比对。
  ///
  /// 比对期间保持显示旧数据（不进入加载态、不清空列表）；只有确认有差异时
  /// 才替换列表并重建页面。请求失败时同样保留旧数据，不打断浏览。
  Future<void> _refreshOnEntry() async {
    if (app.sfwMode || _silentRefreshing) return;
    if (_loading) return; // 已有请求在途，其结果会自行更新列表
    if (_works.isEmpty) {
      // 没有旧数据可展示（首次进入/上次加载失败）：走常规加载。
      await _loadData(reset: true);
      return;
    }
    _silentRefreshing = true;
    // 请求期间条件变化（切歌单、改排序/筛选、分页）则丢弃本次结果。
    final gen = _gen;
    final reviewsMode = _reviewsMode;
    final playlist = _playlist;
    final sort = _reviewSort;
    final asc = _reviewOrderAsc;
    final filter = _reviewFilter;
    try {
      final WorksPage fresh;
      if (reviewsMode) {
        fresh = await ApiService.fetchMyReviews(
          app,
          page: 1,
          perPage: 20,
          order: sort,
          sort: asc ? 'asc' : 'desc',
          filter: filter,
        );
      } else {
        final pl = playlist;
        if (pl == null) return;
        fresh = await ApiService.fetchPlaylistWorks(
          app,
          pl.id,
          page: 1,
          perPage: 20,
        );
      }
      if (!mounted || gen != _gen) return;
      if (_reviewsMode != reviewsMode ||
          !identical(_playlist, playlist) ||
          _reviewSort != sort ||
          _reviewOrderAsc != asc ||
          _reviewFilter != filter) {
        return;
      }
      if (!favoritesListChanged(_works, _totalCount, fresh)) return; // 无差异
      setState(() {
        _clearWorks();
        _appendWorks(fresh.works);
        _visibleTarget = 20;
        _page = 1;
        _hasMore = fresh.hasMore && fresh.works.isNotEmpty;
        _totalCount = fresh.totalCount;
        _error = false;
      });
      if (reviewsMode) app.syncFavorites(_works); // 有新数据才同步收藏状态
      _maybeRefill();
    } catch (_) {
      // 静默刷新失败：继续显示旧数据
    } finally {
      _silentRefreshing = false;
    }
  }

  Future<void> _loadData({bool reset = true}) async {
    if (!mounted) return;
    if (reset) _visibleTarget = 20;
    if (app.sfwMode) {
      setState(() {
        _clearWorks();
        _loading = false;
        _error = false;
        _page = 0;
        _hasMore = false;
      });
      return;
    }
    if (_reviewsMode) {
      await _loadReviews(reset: reset);
    } else {
      await _loadPlaylist(reset: reset);
    }
    _maybeRefill();
  }

  Future<void> _loadReviews({bool reset = true}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final gen = ++_gen;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = false;
      if (reset) {
        _clearWorks();
        _page = 0;
        _hasMore = true;
      }
    });
    try {
      final list = await ApiService.fetchMyReviews(
        app,
        page: page,
        perPage: 20,
        order: _reviewSort,
        sort: _reviewOrderAsc ? 'asc' : 'desc',
        filter: _reviewFilter,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _appendWorks(list.works);
        _page = page;
        _hasMore = list.hasMore && list.works.isNotEmpty;
        _totalCount = list.totalCount;
        _loading = false;
      });
      if (page == 1) {
        app.syncFavorites(_works); // 用我的评价列表同步收藏状态
      }
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _loadPlaylist({bool reset = true}) async {
    final pl = _playlist;
    if (pl == null) return;
    if (!reset && (_loading || !_hasMore)) return;
    final gen = ++_gen;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = false;
      if (reset) {
        _clearWorks();
        _page = 0;
        _hasMore = true;
      }
    });
    try {
      final list = await ApiService.fetchPlaylistWorks(
        app,
        pl.id,
        page: page,
        perPage: 20,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _appendWorks(list.works);
        _page = page;
        _hasMore = list.hasMore && list.works.isNotEmpty;
        _totalCount = list.totalCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _openPlaylistPicker() async {
    if (app.sfwMode) return;
    final picked = await showPlaylistPicker(
      context,
      app: app,
      reviewsMode: _reviewsMode,
      currentId: _playlist?.id,
    );
    if (picked == null || !mounted) return;
    final pl = picked.playlist;
    if (pl == null) {
      if (_reviewsMode) return;
      setState(() {
        _reviewsMode = true;
        _playlist = null;
      });
      _loadData(reset: true);
      return;
    }
    if (!_reviewsMode && pl.id == _playlist?.id) {
      // 同一歌单被编辑（名称/描述/权限变化）时只更新标题信息，不重载内容。
      if (!identical(pl, _playlist)) setState(() => _playlist = pl);
      return;
    }
    setState(() {
      _reviewsMode = false;
      _playlist = pl;
    });
    _loadData(reset: true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBatchTranslation() async {
    if (_batchOpening ||
        !app.customServer ||
        app.customSites.isEmpty ||
        app.sfwMode) {
      return;
    }
    final l10n = context.l10n;
    final epoch = app.serverEpoch;
    final base = ApiService.resolveBase(app);
    final writebackKey =
        app.customSites[app.customServerIdx].lyricsWritebackKey;
    final playlistId = _reviewsMode ? null : _playlist?.id;
    final order = _reviewSort;
    final sort = _reviewOrderAsc ? 'asc' : 'desc';
    final filter = _reviewFilter;
    final token = ApiService.tokenFor(app, base);
    final ages = Set<Age>.of(_ageFilters);
    final query = _query;
    bool sourceChanged() =>
        !mounted ||
        app.serverEpoch != epoch ||
        app.sfwMode ||
        !app.customServer ||
        ApiService.resolveBase(app) != base;
    setState(() => _batchOpening = true);
    try {
      final result = await showDictationBatchImportDialog(
        context,
        sourceChanged: sourceChanged,
        importer: DictationBatchImporter(
          fetchPage: (page) => playlistId == null
              ? ApiService.fetchMyReviews(
                  app,
                  page: page,
                  order: order,
                  sort: sort,
                  filter: filter,
                )
              : ApiService.fetchPlaylistWorks(app, playlistId, page: page),
          fetchTracks: (work) {
            if (!_matchesFavorite(work, ages, query)) {
              return Future.value(const <MediaNode>[]);
            }
            final id = work.apiId;
            if (id == null) throw StateError('Missing work ID: ${work.rj}');
            return ApiService.fetchTracks(app, id, forceRefresh: true);
          },
          fetchLocalLyrics: (work) async => [
            if (_matchesFavorite(work, ages, query))
              for (final file in await LyricsLibraryService.instance.listFiles(
                workId: work.rj,
              ))
                MediaNode(
                  title: file.name,
                  type: 'file',
                  path: file.relativePath,
                ),
          ],
        ),
      );
      if (!mounted || sourceChanged() || result == null) return;
      final queue = DictationQueue.forApp(app);
      var addedTracks = 0;
      var duplicateTracks = 0;
      for (final batch in result.batches) {
        final entry = queue.enqueue(
          work: batch.work,
          tracks: batch.tracks,
          automaticallyMatched: true,
          sourceBase: base,
          lyricsWritebackKey: writebackKey,
          sourceHeaders: token == null || token.isEmpty
              ? const {}
              : {'Authorization': 'Bearer $token'},
        );
        addedTracks += entry?.tracks.length ?? 0;
        duplicateTracks += batch.tracks.length - (entry?.tracks.length ?? 0);
      }
      _toast(
        l10n.batchTranslationSummary(
          addedTracks.toString(),
          (result.skippedTracks + duplicateTracks).toString(),
          result.failedWorks.length.toString(),
        ),
      );
      if (queue.entries.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DictationTranslationPage(app: app)),
      );
    } finally {
      if (mounted) setState(() => _batchOpening = false);
    }
  }

  /// 歌单模式下的标题栏操作；「收藏」模式保持原有控件不变。
  List<Widget> _playlistHeaderActions() {
    final pl = _playlist;
    if (pl == null) return const [];
    return [
      if (pl.isOwned)
        IconButton(
          onPressed: _addWorksByRj,
          tooltip: context.l10n.favoritesPagePlaylistHeaderActionsTooltip3,
          icon: Icon(Icons.add, size: 22, color: p.accent),
        )
      else
        IconButton(
          onPressed: _removeCurrentLikedPlaylist,
          tooltip: context.l10n.favoritesPagePlaylistHeaderActionsTooltip2,
          icon: Icon(Icons.favorite, size: 21, color: p.red),
        ),
      IconButton(
        onPressed: _copyCurrentShareLink,
        tooltip: context.l10n.favoritesPagePlaylistHeaderActionsTooltip,
        icon: Icon(Icons.link, size: 21, color: p.accent),
      ),
    ];
  }

  void _copyCurrentShareLink() {
    final pl = _playlist;
    if (pl == null) return;
    Clipboard.setData(ClipboardData(text: ApiService.playlistShareLink(pl.id)));
    _toast(context.l10n.shareLinkCopied);
  }

  Future<void> _addWorksByRj() async {
    final l10n = context.l10n;
    final pl = _playlist;
    if (pl == null) return;
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.favoritesPageInputText),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            style: TextStyle(fontSize: 13, color: p.text),
            decoration: InputDecoration(
              hintText: l10n.favoritesPageInputHintText,
              hintStyle: TextStyle(fontSize: 12.5, color: p.dim),
              filled: true,
              fillColor: p.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
    if (input == null || !mounted) return;
    final rjs = RegExp(
      r'RJ\d{5,}',
      caseSensitive: false,
    ).allMatches(input.toUpperCase()).map((m) => m.group(0)!).toSet().toList();
    if (rjs.isEmpty) {
      _toast(l10n.favoritesPageAddWorksByRjToast2);
      return;
    }
    try {
      await ApiService.addWorksToPlaylist(app, pl.id, rjs);
      if (!mounted) return;
      _toast(l10n.favoritesPageAddWorksByRjToast3((rjs.length).toString()));
      _loadData(reset: true);
    } catch (e) {
      if (mounted) _toast(l10n.favoritesPageAddWorksByRjToast((e).toString()));
    }
  }

  Future<void> _removeCurrentLikedPlaylist() async {
    final l10n = context.l10n;
    final pl = _playlist;
    if (pl == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.favoritesPageLabelLabel),
        content: Text(l10n.favoritesPageOkText),
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
    try {
      await ApiService.removeLikedPlaylist(app, pl.id);
      if (!mounted) return;
      setState(() {
        _reviewsMode = true;
        _playlist = null;
        _clearWorks();
      });
      _loadData(reset: true);
    } catch (e) {
      if (mounted) {
        _toast(
          l10n.favoritesPageRemoveCurrentLikedPlaylistToast((e).toString()),
        );
      }
    }
  }

  /// 当前列表是否支持多选管理：收藏与自建列表可用，导入的歌单不可管理。
  bool get _canManageWorks => _reviewsMode || (_playlist?.isOwned ?? false);

  void _enterSelecting(Work work) {
    if (!_canManageWorks) return;
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(work.rj);
    });
  }

  void _toggleSelected(Work work) {
    setState(() {
      if (!_selected.remove(work.rj)) _selected.add(work.rj);
    });
  }

  void _exitSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _visibleWorks.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_visibleWorks.map((w) => w.rj));
      }
    });
  }

  Future<void> _removeSelectedWorks() async {
    final l10n = context.l10n;
    final reviews = _reviewsMode;
    final pl = _playlist;
    if (_selected.isEmpty) return;
    if (!reviews && pl == null) return;
    final label = reviews
        ? l10n.favoritesPageLabelLabel
        : l10n.favoritesPageLabelLabel2;
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(label),
        content: Text(
          l10n.favoritesPageOkText2((count).toString(), (label).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              label,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final works = _works
        .where((w) => _selected.contains(w.rj))
        .toList(growable: false);
    try {
      if (reviews) {
        for (final work in works) {
          try {
            await ApiService.deleteReview(app, work);
          } catch (_) {
            // 单个删除失败时继续处理剩余作品。
          }
        }
      } else {
        final ids = works
            .map((w) => w.apiId?.toString())
            .whereType<String>()
            .toList();
        if (ids.isEmpty) {
          _toast(l10n.favoritesPageRemoveSelectedWorksToast);
          return;
        }
        await ApiService.removeWorksFromPlaylist(app, pl!.id, ids);
      }
      if (!mounted) return;
      _exitSelecting();
      _toast(
        l10n.favoritesPageRemoveSelectedWorksToast3(
          (label).toString(),
          (works.length).toString(),
        ),
      );
      _loadData(reset: true);
    } catch (e) {
      if (mounted) {
        _toast(
          l10n.favoritesPageRemoveSelectedWorksToast2(
            (label).toString(),
            (e).toString(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _reviewsMode
        ? context.l10n.favorites
        : (_playlist?.name ?? context.l10n.favorites);
    if (_selected.isNotEmpty) {
      _selected.retainAll(_visibleWorks.map((w) => w.rj));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selecting)
          _selectionBar()
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _searching
                      ? context.l10n.downloadsPageBuildTooltip
                      : context.l10n.favoritesSearch,
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() => _searching = !_searching);
                    if (!_searching) {
                      _searchFocus.unfocus();
                      _search.clear();
                      _applyViewFilter();
                    }
                  },
                ),
                if (!_reviewsMode && _playlist != null)
                  ..._playlistHeaderActions(),
                if (app.customServer &&
                    app.customSites.isNotEmpty &&
                    !app.sfwMode)
                  IconButton(
                    onPressed: _batchOpening || _visibleWorks.isEmpty
                        ? null
                        : _openBatchTranslation,
                    tooltip: context.l10n.batchTranslation,
                    icon: Icon(
                      Icons.translate,
                      size: 22,
                      color: _batchOpening || _visibleWorks.isEmpty
                          ? p.dim
                          : p.accent,
                    ),
                  ),
                IconButton(
                  onPressed: _openPlaylistPicker,
                  tooltip: context.l10n.favoritesPageBuildTooltip,
                  icon: Icon(Icons.queue_music, size: 22, color: p.accent),
                ),
              ],
            ),
          ),
          _reviewToolbar(),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: FavoritesSearchField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: _applyViewFilter,
              ),
            ),
        ],
        Expanded(child: _body()),
      ],
    );
  }

  Widget _selectionBar() {
    final count = _selected.length;
    final allSelected =
        _visibleWorks.isNotEmpty && count == _visibleWorks.length;
    final label = _reviewsMode
        ? context.l10n.favoritesPageLabelLabel
        : context.l10n.favoritesPageLabelLabel2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _exitSelecting,
            tooltip: context.l10n.exitSelection,
            icon: Icon(Icons.arrow_back, size: 22, color: p.text),
          ),
          Expanded(
            child: Text(
              context.l10n.favoritesPageSelectionBarText((count).toString()),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _visibleWorks.isEmpty ? null : _selectAll,
            tooltip: allSelected
                ? context.l10n.deselectAll
                : context.l10n.selectAll,
            icon: Icon(
              allSelected ? Icons.deselect : Icons.select_all,
              size: 22,
              color: p.muted,
            ),
          ),
          IconButton(
            onPressed: count == 0 ? null : _removeSelectedWorks,
            tooltip: label,
            icon: Icon(
              Icons.delete_outline,
              size: 22,
              color: count == 0 ? p.dim : p.red,
            ),
          ),
          IconButton(
            onPressed: _exitSelecting,
            tooltip: context.l10n.exitSelection,
            icon: Icon(Icons.close, size: 22, color: p.muted),
          ),
        ],
      ),
    );
  }

  static Map<String, String> get _reviewSortLabels => {
    'updated_at': appL10n.favoritesPageReviewSortLabelsReviewSortLabels5,
    'userRating': appL10n.favoritesPageReviewSortLabelsReviewSortLabels4,
    'release': appL10n.favoritesPageReviewSortLabelsReviewSortLabels3,
    'review_count': appL10n.favoritesPageReviewSortLabelsReviewSortLabels,
    'dl_count': appL10n.favoritesPageReviewSortLabelsReviewSortLabels2,
    'nsfw': appL10n.ageRating,
  };

  static Map<String, String> get _reviewFilterLabels => <String, String>{
    '': appL10n.all,
    'marked': appL10n.wantToListen,
    'listening': appL10n.listening,
    'listened': appL10n.listened,
    'replay': appL10n.replay,
    'postponed': appL10n.postponed,
  };

  Widget _reviewToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _reviewFilterButton(),
            if (_reviewsMode) ...[
              const SizedBox(width: 8),
              _reviewSortDropdown(),
              const SizedBox(width: 8),
              _reviewOrderButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewFilterButton() {
    final active =
        (_reviewsMode && _reviewFilter != null) ||
        (_ageFilters.isNotEmpty && _ageFilters.length < 3);
    return PopupMenuButton<String>(
      tooltip: context.l10n.widgetsFilterButtonTooltip,
      // 悬停高亮跟随 child（MenuItem）的圆角，否则从圆角缺口漏出方形灰影
      borderRadius: BorderRadius.circular(11),
      onSelected: (value) {
        if (value.startsWith('age:')) {
          final age = Age.values[int.parse(value.substring(4))];
          if (!_ageFilters.remove(age)) _ageFilters.add(age);
          _applyViewFilter();
          return;
        }
        final filter = value.isEmpty ? null : value;
        if (_reviewFilter == filter) return;
        setState(() => _reviewFilter = filter);
        _loadData(reset: true);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: (ctx) => [
        if (_reviewsMode) ...[
          ..._reviewFilterLabels.entries.map(
            (entry) => PopupMenuItem<String>(
              value: entry.key,
              height: 42,
              child: MenuItem(
                label: entry.value,
                selected: entry.key.isEmpty
                    ? _reviewFilter == null
                    : _reviewFilter == entry.key,
              ),
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(
            context.l10n.ageRating,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.dim,
            ),
          ),
        ),
        for (final age in [Age.r18, Age.r15, Age.all])
          PopupMenuItem<String>(
            value: 'age:${age.index}',
            height: 44,
            child: MenuItem(
              label: age == Age.all
                  ? context.l10n.allAges
                  : age.name.toUpperCase(),
              selected: _ageFilters.contains(age),
              checkbox: true,
            ),
          ),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: active ? p.accent : p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(Icons.tune, size: 17, color: active ? p.accent : p.muted),
      ),
    );
  }

  Widget _reviewSortDropdown() {
    return PopupMenuButton<String>(
      tooltip: context.l10n.favoritesPageReviewSortDropdownTooltip,
      // 悬停高亮跟随 child（MenuItem）的圆角，否则从圆角缺口漏出方形灰影
      borderRadius: BorderRadius.circular(11),
      onSelected: (value) {
        if (_reviewSort == value) return;
        setState(() => _reviewSort = value);
        _loadData(reset: true);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: (ctx) => _reviewSortLabels.entries
          .map(
            (entry) => PopupMenuItem(
              value: entry.key,
              height: 42,
              child: MenuItem(
                label: entry.value,
                selected: _reviewSort == entry.key,
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _reviewSortLabels[_reviewSort]!,
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 15, color: p.dim),
          ],
        ),
      ),
    );
  }

  Widget _reviewOrderButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _reviewOrderAsc = !_reviewOrderAsc);
        _loadData(reset: true);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: _reviewOrderAsc ? p.accent : p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          _reviewOrderAsc ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: _reviewOrderAsc ? p.accent : p.muted,
        ),
      ),
    );
  }

  Widget _body() {
    if (app.sfwMode) {
      return Center(
        child: Text(
          context.l10n.favoritesPageBodyText5,
          style: TextStyle(fontSize: 13, color: p.dim),
        ),
      );
    }
    if ((_loading || _filterTimer?.isActive == true) && _visibleWorks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: p.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.loading,
              style: TextStyle(fontSize: 13, color: p.dim),
            ),
          ],
        ),
      );
    }
    if (_error && _visibleWorks.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _loadData(reset: true),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 34, color: p.dim),
              const SizedBox(height: 10),
              Text(
                context.l10n.favoritesPageBodyText6,
                style: TextStyle(fontSize: 13, color: p.dim),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.favoritesPageBodyText,
                style: TextStyle(fontSize: 11.5, color: p.accent),
              ),
            ],
          ),
        ),
      );
    }
    if (_visibleWorks.isEmpty) {
      return Center(
        child: Text(
          _hasViewFilter
              ? context.l10n.homePageSearchResultsViewText2
              : _reviewsMode
              ? context.l10n.favoritesPageBodyText3
              : context.l10n.favoritesPageBodyText4,
          style: TextStyle(fontSize: 13, color: p.dim),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
                _loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => _loadData(reset: true),
              child: ResponsiveGrid(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 30),
                itemCount: _visibleWorks.length,
                itemBuilder: (ctx, i) {
                  final w = _visibleWorks[i];
                  final selected = _selected.contains(w.rj);
                  return GestureDetector(
                    onLongPress: !_selecting && _canManageWorks
                        ? () => _enterSelecting(w)
                        : null,
                    child: Stack(
                      children: [
                        WorkCard(
                          work: w,
                          index: i,
                          cardBackground: true,
                          onTap: _selecting
                              ? () => _toggleSelected(w)
                              : () => Navigator.of(
                                  context,
                                ).push(buildWorkRoute(app, w)),
                        ),
                        if (_selecting)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(6),
                              child: Checkbox(
                                value: selected,
                                onChanged: (_) => _toggleSelected(w),
                                activeColor: p.accent,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              context.l10n.loading,
              style: TextStyle(fontSize: 12, color: p.dim),
            ),
          )
        else if (!_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              context.l10n.favoritesPageBodyText2,
              style: TextStyle(fontSize: 12, color: p.dim),
            ),
          ),
      ],
    );
  }
}
