import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';
import '../sheets.dart';

class HomePage extends StatefulWidget {
  final AppState app;
  const HomePage({super.key, required this.app});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _loadedSig = '';
  String _loadedDataSig = ''; // 已渲染的列表数据签名（补页/加载状态变化时刷新）

  // 真实搜索状态
  final List<Work> _searchResults = [];
  bool _searchLoading = false;
  bool _searchHasMore = true;
  int _searchPage = 0;
  bool _searchError = false;
  String _searchQuery = '';
  int _searchSeq = 0;
  int _worksGen = 0; // 作品列表代次：切换服务器/筛选后使在途补页失效
  late int _seenEpoch;
  late int _seenHomeRefreshVersion;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _seenEpoch = app.serverEpoch;
    _seenHomeRefreshVersion = app.homeRefreshVersion;
    _loadedSig = _filterSig;
    _loadedDataSig = _dataSig;
    app.addListener(_onAppChanged);
    // 首帧后再加载，避免 initState 阶段同步 notify 触发 build 期 setState 断言
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemote());
  }

  /// 首页网格渲染依赖的列表数据/加载状态签名
  String get _dataSig =>
      '${app.remoteWorks.length}|${app.loadingRemote}|${app.worksLoadingMore}|'
      '${app.remoteError}|${app.worksHasMore}';

  void _onAppChanged() {
    if (app.homeRefreshVersion != _seenHomeRefreshVersion) {
      _seenHomeRefreshVersion = app.homeRefreshVersion;
      _loadRemote();
      return;
    }
    if (app.takePendingClear()) {
      _clearSearchState();
      if (mounted) setState(() {});
      return;
    }
    final pending = app.peekPendingSearch();
    if (pending != null) {
      _runSearch(pending);
      return;
    }
    if (app.serverEpoch != _seenEpoch) {
      _seenEpoch = app.serverEpoch;
      _loadedSig = _filterSig;
      _clearSearchState();
      _loadRemote();
      return;
    }
    if (_filterSig != _loadedSig) {
      _loadedSig = _filterSig;
      if (_searchQuery.isNotEmpty) {
        _runSearch(_searchQuery);
      } else {
        _loadRemote();
      }
      return;
    }
    // 列表数据/加载状态变化（补页、加载中提示等）时刷新。
    // 此前依赖根级 ListenableBuilder 的全树重建，现已改为仅首页按需重建。
    final sig = _dataSig;
    if (sig != _loadedDataSig) {
      _loadedDataSig = sig;
      if (mounted) setState(() {});
    }
  }

  String get _filterSig =>
      '${app.serverEpoch}|${app.category}|${app.sort}|${app.orderAsc}|${app.subOnly}|${app.ageFilter}';

  Future<void> _loadRemote() async {
    final gen = ++_worksGen;
    app.worksLoadingMore = false; // 丢弃在途补页
    // 切换服务器/排序/筛选后先清空旧数据，避免新请求失败时残留上一台服务器的内容
    app.remoteWorks = [];
    app.worksPage = 0;
    app.worksHasMore = true;
    app.remoteError = null;
    if (app.category == 'rec' && app.randomSeed == null) {
      app.randomSeed = DateTime.now().millisecondsSinceEpoch % 1000000;
    }
    app.loadingRemote = true;
    app.notify();
    try {
      final res = await ApiService.fetchWorks(app);
      if (gen != _worksGen) return; // 已被新的加载取代
      app.remoteWorks = res.works;
      app.remoteError = null;
      app.loadingRemote = false;
      app.worksPage = 1;
      app.worksHasMore = res.hasMore;
      app.notify();
      if (mounted) setState(() {});
      _maybeRefill();
    } catch (e) {
      if (gen != _worksGen) return;
      app.remoteError = e.toString();
      app.loadingRemote = false;
      app.notify();
    }
  }

  Future<void> _loadMore() async {
    if (app.worksLoadingMore || !app.worksHasMore || app.remoteWorks.isEmpty) {
      return;
    }
    final gen = _worksGen;
    app.worksLoadingMore = true;
    app.notify();
    try {
      final page = await ApiService.fetchWorks(
        app,
        page: app.worksPage + 1,
        perPage: 20,
      );
      if (gen != _worksGen) return; // 列表已被重置，丢弃过期结果
      if (page.works.isEmpty) {
        app.worksHasMore = false;
      } else {
        app.worksPage++;
        app.remoteWorks.addAll(page.works);
        app.worksHasMore = page.hasMore;
      }
    } catch (_) {
      if (gen == _worksGen) app.worksHasMore = false;
    } finally {
      if (gen == _worksGen) {
        app.worksLoadingMore = false;
        app.notify();
        _maybeRefill();
      }
    }
  }

  /// 年龄分级是客户端过滤：过滤后不足一页时继续补拉（最多 10 页），直到凑够一页或拉完
  void _maybeRefill() {
    if (app.ageFilter == null) return;
    if (!app.worksHasMore || app.worksPage >= 10) return;
    if (app.homeOrder.length >= 20) return;
    _loadMore();
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  String get serverLabel => app.customServer
      ? (app.customSites.isNotEmpty
            ? app.customSites[app.customServerIdx].alias
            : '自建')
      : 'asmr.one';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: [
              // 排序行 + 作品网格（顶部留出搜索栏空间）
              Positioned(
                top: 58,
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  children: [
                    _sortRow(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Stack(
                        children: [
                          // 有搜索时直接展示搜索结果，否则展示作品列表
                          if (_searchQuery.isNotEmpty)
                            _searchResultsView()
                          else
                            _grid(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Kikoeta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: app.toggleSfw,
          tooltip: app.sfwMode ? 'SFW 模式已开启：仅显示全年龄内容' : '开启 SFW 模式（仅显示全年龄内容）',
          icon: Icon(
            app.sfwMode
                ? Icons.family_restroom
                : Icons.family_restroom_outlined,
            size: 20,
            color: app.sfwMode ? p.accent : p.muted,
          ),
        ),
        IconButton(
          onPressed: () => Theme.of(context).brightness == Brightness.dark
              ? _setTheme(Brightness.light)
              : _setTheme(Brightness.dark),
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            size: 20,
            color: p.muted,
          ),
        ),
        Pill(
          label: serverLabel,
          selected: true,
          onTap: () => showServerSheet(context, app),
        ),
      ],
    );
  }

  void _setTheme(Brightness b) {
    app.setThemeMode(b == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
  }

  void _clearSearchState() {
    _searchResults.clear();
    _searchQuery = '';
    _searchLoading = false;
    _searchError = false;
    _searchPage = 0;
    _searchHasMore = true;
  }

  PopupMenuItem<T> _menuHead<T>(String title) {
    return PopupMenuItem<T>(
      enabled: false,
      height: 30,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
            color: p.dim,
          ),
        ),
      ),
    );
  }

  Widget _sortRow() {
    final labels = {'all': '全部', 'hot': '热门', 'rec': '推荐'};
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: labels.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill(
                        label: e.value,
                        selected: app.category == e.key,
                        onTap: () {
                          if (e.key == 'rec') {
                            app.randomSeed =
                                DateTime.now().millisecondsSinceEpoch % 1000000;
                          }
                          app.setCategory(e.key);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        _sortDropdown(),
        const SizedBox(width: 8),
        _orderButton(),
      ],
    );
  }

  static const sortLabels = {
    'collect': '收录时间',
    'date': '发布时间',
    'myrating': '我的评价',
    'sales': '销售数量',
    'price': '销售价格',
    'rating': '总评价',
    'comments': '评论数量',
    'rj': 'RJ号',
  };

  Widget _sortDropdown() {
    return PopupMenuButton<String>(
      tooltip: '排序方式',
      initialValue: app.sort,
      onSelected: (v) {
        app.setSort(v);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: (ctx) => [
        _menuHead('排序方式'),
        ...sortLabels.entries.map(
          (e) => PopupMenuItem(
            value: e.key,
            height: 44,
            child: MenuItem(label: e.value, selected: app.sort == e.key),
          ),
        ),
      ],
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
              sortLabels[app.sort]!,
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 15, color: p.dim),
          ],
        ),
      ),
    );
  }

  Widget _orderButton() {
    return GestureDetector(
      onTap: () => app.setOrderAsc(!app.orderAsc),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: app.orderAsc ? p.accent : p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          app.orderAsc ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: app.orderAsc ? p.accent : p.muted,
        ),
      ),
    );
  }

  Widget _grid() {
    final order = app.homeOrder;
    final list = app.homeList;
    return order.isEmpty
        ? (app.loadingRemote &&
                  app.remoteWorks.isEmpty &&
                  app.remoteError == null
              ? _skeletonGrid()
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // 网络错误时点击空白处重试连接
                    if (app.remoteError != null && !app.loadingRemote) {
                      _loadRemote();
                    }
                  },
                  child: Center(child: _emptyHint()),
                ))
        : Column(
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
                    onRefresh: _loadRemote,
                    child: ResponsiveGrid(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 10, bottom: 30),
                      itemCount: order.length,
                      itemBuilder: (ctx, i) {
                        final idx = order[i];
                        final w = list[idx];
                        return WorkCard(
                          work: w,
                          index: idx,
                          cardBackground: true,
                          onTap: () => Navigator.of(
                            context,
                          ).push(buildWorkRoute(app, w)),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (app.worksLoadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '加载中…',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                )
              else if (!app.worksHasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '已显示全部作品',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ),
            ],
          );
  }

  Widget _emptyHint() {
    final String msg;
    if (app.loadingRemote || app.worksLoadingMore) {
      msg = '正在加载…';
    } else if (app.remoteError != null) {
      msg = '无网络连接，请检查网络或服务器设置';
    } else if (app.ageFilter != null || app.subOnly) {
      msg = '当前筛选条件下暂无作品';
    } else {
      msg = '暂无作品';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        app.loadingRemote || app.worksLoadingMore
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: p.accent,
                ),
              )
            : Icon(
                app.remoteError != null ? Icons.wifi_off : Icons.inbox_outlined,
                size: 34,
                color: p.dim,
              ),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 13, color: p.dim)),
        if (app.remoteError != null && !app.loadingRemote)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '点击任意处重试',
              style: TextStyle(fontSize: 11.5, color: p.accent),
            ),
          ),
      ],
    );
  }

  /// 首次加载作品列表时的骨架屏
  Widget _skeletonGrid() {
    return Pulse(
      child: ResponsiveGrid(
        padding: const EdgeInsets.only(top: 10, bottom: 30),
        itemCount: 8,
        itemBuilder: (ctx, i) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: SkeletonBox(height: double.infinity, radius: 14),
              ),
              const SizedBox(height: 8),
              SkeletonBox(height: 12, width: double.infinity),
              const SizedBox(height: 6),
              SkeletonBox(height: 10, width: 90),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runSearch(String q, {bool reset = true}) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _searchQuery = '';
        _searchLoading = false;
        _searchError = false;
        _searchPage = 0;
        _searchHasMore = true;
      });
      return;
    }
    if (!reset && (_searchLoading || !_searchHasMore)) return;
    final seq = ++_searchSeq;
    setState(() {
      _searchQuery = query;
      _searchLoading = true;
      if (reset) {
        _searchError = false;
        _searchResults.clear();
        _searchPage = 0;
        _searchHasMore = true;
      }
    });
    final targetPage = reset ? 1 : _searchPage + 1;
    try {
      final list = await ApiService.searchWorks(app, query, page: targetPage);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searchResults.addAll(list.works);
        _searchPage = targetPage;
        _searchHasMore = list.hasMore;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searchLoading = false;
        _searchError = true;
      });
    }
    // 年龄分级是客户端过滤：结果不足一页时继续补拉（最多 4 页）
    if (app.ageFilter != null &&
        _searchHasMore &&
        !_searchLoading &&
        _searchPage < 4) {
      final visible = _visibleSearchResults.length;
      if (visible < 20) _runSearch(_searchQuery, reset: false);
    }
  }

  List<Work> get _visibleSearchResults {
    final res = _searchResults.where((w) => !app.isBlacklistedWork(w)).toList();
    if (app.ageFilter == null) return res;
    return res.where((w) => w.age.index == app.ageFilter).toList();
  }

  /// 搜索结果显示在主内容区（可滚动、分页加载）
  Widget _searchResultsView() {
    if (_searchLoading && _searchResults.isEmpty) {
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
            Text('搜索中…', style: TextStyle(fontSize: 13, color: p.dim)),
          ],
        ),
      );
    }
    if (_searchError && _searchResults.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_searchLoading) _runSearch(_searchQuery);
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 34, color: p.dim),
              const SizedBox(height: 10),
              Text(
                '无网络连接，请检查网络或服务器设置',
                style: TextStyle(fontSize: 13, color: p.dim),
              ),
              const SizedBox(height: 8),
              Text('点击重试', style: TextStyle(fontSize: 11.5, color: p.accent)),
            ],
          ),
        ),
      );
    }
    final res = _visibleSearchResults;
    if (res.isEmpty) {
      return Center(
        child: Text('没有找到相关作品', style: TextStyle(fontSize: 13, color: p.dim)),
      );
    }
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
                _runSearch(_searchQuery, reset: false);
              }
              return false;
            },
            child: ResponsiveGrid(
              padding: const EdgeInsets.only(top: 10, bottom: 30),
              itemCount: res.length,
              itemBuilder: (ctx, i) {
                final w = res[i];
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
        if (_searchLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('加载中…', style: TextStyle(fontSize: 12, color: p.dim)),
          )
        else if (!_searchHasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '已显示全部搜索结果',
              style: TextStyle(fontSize: 12, color: p.dim),
            ),
          ),
      ],
    );
  }
}
