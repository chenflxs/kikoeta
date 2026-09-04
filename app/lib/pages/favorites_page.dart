import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';

const _reviewsEntryId = '__REVIEWS__';

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
  bool _loading = false;
  bool _error = false;
  bool _hasMore = true;
  int _page = 0;
  int _gen = 0;
  String _reviewSort = 'updated_at';
  bool _reviewOrderAsc = false;
  String? _reviewFilter;
  late int _seenFavVersion;
  late int _seenFavoritesEntryVersion;
  late bool _seenSfwMode;

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
    app.removeListener(_onAppChanged);
    super.dispose();
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
          _works.clear();
          _loading = false;
          _error = false;
          _page = 0;
          _hasMore = false;
        });
      }
      return;
    }
    _loadData(reset: true);
  }

  Future<void> _loadData({bool reset = true}) async {
    if (app.sfwMode) {
      if (!mounted) return;
      setState(() {
        _works.clear();
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
  }

  Future<void> _loadReviews({bool reset = true}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final gen = ++_gen;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      if (reset) {
        _error = false;
        _works.clear();
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
        _works.addAll(list.works);
        _page = page;
        _hasMore = list.hasMore;
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
      if (reset) {
        _error = false;
        _works.clear();
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
        _works.addAll(list.works);
        _page = page;
        _hasMore = list.hasMore;
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
    List<PlaylistInfo> list;
    try {
      list = await ApiService.fetchPlaylists(app);
    } catch (_) {
      list = const [];
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Text(
                  '选择歌单',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    _pickerItem(
                      id: _reviewsEntryId,
                      name: '收藏',
                      subtitle: '我的评价/收藏（所有作品）',
                      selected: _reviewsMode,
                      icon: Icons.favorite,
                    ),
                    const Divider(height: 1),
                    ...list.map((pl) {
                      final selected = !_reviewsMode && pl.id == _playlist?.id;
                      return _pickerItem(
                        id: pl.id,
                        name: pl.name,
                        subtitle: '${pl.worksCount} 个作品',
                        selected: selected,
                        icon: Icons.queue_music,
                        coverUrl: pl.coverUrl,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (picked == _reviewsEntryId) {
      if (_reviewsMode) return;
      setState(() {
        _reviewsMode = true;
        _playlist = null;
      });
      _loadData(reset: true);
      return;
    }
    if (!_reviewsMode && picked == _playlist?.id) return;
    PlaylistInfo? pl;
    for (final x in list) {
      if (x.id == picked) {
        pl = x;
        break;
      }
    }
    if (pl == null) return;
    setState(() {
      _reviewsMode = false;
      _playlist = pl;
    });
    _loadData(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _reviewsMode ? '收藏' : (_playlist?.name ?? '收藏');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                onPressed: _openPlaylistPicker,
                tooltip: '切换歌单',
                icon: Icon(Icons.queue_music, size: 22, color: p.accent),
              ),
            ],
          ),
        ),
        if (_reviewsMode) _reviewToolbar(),
        Expanded(child: _body()),
      ],
    );
  }

  static const _reviewSortLabels = {
    'updated_at': '标记时间',
    'userRating': '我的评价',
    'release': '发布时间',
    'review_count': '评论数量',
    'dl_count': '销售数量',
    'nsfw': '年龄分级',
  };

  static const _reviewFilterLabels = <String, String>{
    '': '全部',
    'marked': '想听',
    'listening': '在听',
    'listened': '听过',
    'replay': '重听',
    'postponed': '搁置',
  };

  Widget _reviewToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _reviewFilterButton(),
            const SizedBox(width: 8),
            _reviewSortDropdown(),
            const SizedBox(width: 8),
            _reviewOrderButton(),
          ],
        ),
      ),
    );
  }

  Widget _reviewFilterButton() {
    return PopupMenuButton<String>(
      tooltip: '进度筛选',
      initialValue: _reviewFilter ?? '',
      onSelected: (value) {
        final filter = value.isEmpty ? null : value;
        if (_reviewFilter == filter) return;
        setState(() => _reviewFilter = filter);
        _loadData(reset: true);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: (ctx) => _reviewFilterLabels.entries
          .map(
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
          )
          .toList(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: _reviewFilter != null ? p.accent : p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          Icons.tune,
          size: 17,
          color: _reviewFilter != null ? p.accent : p.muted,
        ),
      ),
    );
  }

  Widget _reviewSortDropdown() {
    return PopupMenuButton<String>(
      tooltip: '排序方式',
      initialValue: _reviewSort,
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
          'SFW 模式下不显示收藏内容',
          style: TextStyle(fontSize: 13, color: p.dim),
        ),
      );
    }
    if (_loading && _works.isEmpty) {
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
            Text('加载中…', style: TextStyle(fontSize: 13, color: p.dim)),
          ],
        ),
      );
    }
    if (_error && _works.isEmpty) {
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
                '加载失败，请确认已在设置中登录',
                style: TextStyle(fontSize: 13, color: p.dim),
              ),
              const SizedBox(height: 8),
              Text('点击重试', style: TextStyle(fontSize: 11.5, color: p.accent)),
            ],
          ),
        ),
      );
    }
    if (_works.isEmpty) {
      return Center(
        child: Text('还没有收藏的作品', style: TextStyle(fontSize: 13, color: p.dim)),
      );
    }
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
                _loadData(reset: false);
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => _loadData(reset: true),
              child: ResponsiveGrid(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 30),
                itemCount: _works.length,
                itemBuilder: (ctx, i) {
                  final w = _works[i];
                  return WorkCard(
                    work: w,
                    index: i,
                    cardBackground: true,
                    onTap: () =>
                        Navigator.of(context).push(buildWorkRoute(app, w)),
                  );
                },
              ),
            ),
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('加载中…', style: TextStyle(fontSize: 12, color: p.dim)),
          )
        else if (!_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('已显示全部', style: TextStyle(fontSize: 12, color: p.dim)),
          ),
      ],
    );
  }

  Widget _pickerItem({
    required String id,
    required String name,
    required String subtitle,
    required bool selected,
    required IconData icon,
    String? coverUrl,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
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
                        errorBuilder: (_, _, _) => _plIcon(p),
                      )
                    : Container(
                        color: p.surface2,
                        child: Icon(icon, size: 18, color: p.accent),
                      ),
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
                  Text(subtitle, style: TextStyle(fontSize: 11, color: p.dim)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }

  Widget _plIcon(Palette p) {
    return Container(
      color: p.surface2,
      child: Icon(Icons.queue_music, size: 18, color: p.dim),
    );
  }
}
