import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../services/lyrics_library_service.dart';
import '../services/theme_reveal.dart';
import '../services/works_page_buffer.dart';
import '../subpage_swipe.dart';
import '../theme.dart';
import '../widgets.dart';
import '../sheets.dart';
import '../l10n/strings.dart';

class HomePage extends StatefulWidget {
  final AppState app;
  const HomePage({super.key, required this.app});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _categories = ['all', 'hot', 'rec'];
  String _loadedSig = '';
  String _homeFilterSig = ''; // 首页数据对应的筛选；搜索期间可能与当前筛选不同
  String _loadedDataSig = ''; // 已渲染的列表数据签名（补页/加载状态变化时刷新）

  // 真实搜索状态
  final List<Work> _searchResults = [];
  bool _searchLoading = false;
  bool _searchHasMore = true;
  int _searchPage = 0;
  int? _searchRandomSeed;
  bool _searchError = false;
  String _searchQuery = '';
  WorksPageBuffer? _searchPages;
  WorksPageBuffer? _homePages;
  bool _searchAppending = false;
  bool _homeAppending = false;
  bool _homeAppendError = false;
  final Set<String> _localSubtitleWorkIds = <String>{};
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
    LyricsLibraryService.instance.revision.addListener(
      _onSubtitleLibraryChanged,
    );
    _loadLocalSubtitleIds();
    // 首帧后再加载，避免 initState 阶段同步 notify 触发 build 期 setState 断言
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemote());
  }

  /// 首页网格渲染依赖的列表数据/加载状态签名
  String get _dataSig =>
      '${app.remoteWorks.length}|${app.loadingRemote}|${app.worksLoadingMore}|'
      '${app.remoteError}|${app.worksHasMore}';

  void _onAppChanged() {
    var reloadHome = false;
    // 清空/新搜索必须优先于首页刷新事件处理，避免刷新分支提前 return
    // 导致搜索状态一直残留。
    if (app.takePendingClear()) {
      _clearSearchState();
      reloadHome = _homeFilterSig != _filterSig;
      if (mounted) setState(() {});
      // 同一次通知也可能包含「再次点击首页」的刷新请求，继续处理。
    }
    final pending = app.peekPendingSearch();
    if (pending != null) {
      _runSearch(pending);
      return;
    }
    if (app.homeRefreshVersion != _seenHomeRefreshVersion) {
      _seenHomeRefreshVersion = app.homeRefreshVersion;
      if (app.isDlsite && _searchQuery.isNotEmpty) {
        _runSearch(_searchQuery);
      } else {
        _loadRemote();
      }
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
    if (reloadHome) {
      _loadRemote();
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

  String get _filterSig {
    final ages = app.ageFilters.toList()..sort();
    final subtitle = app.isDlsite ? SubtitleFilter.none : app.subtitleFilter;
    return '${app.serverEpoch}|${app.category}|${app.sort}|${app.orderAsc}|$subtitle|$ages';
  }

  Future<void> _loadLocalSubtitleIds() async {
    final records = await LyricsLibraryService.instance.records();
    if (!mounted) return;
    final ids = records.map((record) => record.workId.toUpperCase()).toSet();
    if (ids.length == _localSubtitleWorkIds.length &&
        ids.containsAll(_localSubtitleWorkIds)) {
      return;
    }
    _localSubtitleWorkIds
      ..clear()
      ..addAll(ids);
    setState(() {});
    if (!app.isDlsite && app.subtitleFilter == SubtitleFilter.all) {
      _maybeRefill();
      _maybeRefillSearch();
    }
  }

  void _onSubtitleLibraryChanged() {
    _loadLocalSubtitleIds();
  }

  Future<void> _loadRemote() async {
    if (!mounted) return;
    _homePages?.close();
    final pages = WorksPageBuffer(
      (page) => ApiService.fetchWorks(app, page: page),
    );
    _homePages = pages;
    _loadedSig = _filterSig;
    _homeFilterSig = _loadedSig;
    _homeAppending = false;
    _homeAppendError = false;
    app.worksLoadingMore = false;
    // 切换服务器/排序/筛选后先清空旧数据，避免新请求失败时残留上一台服务器的内容
    app.remoteWorks = [];
    app.worksPage = 0;
    app.worksHasMore = true;
    app.remoteError = null;
    if (app.sort == 'random') {
      app.randomSeed = app.nextRandomSeed(app.randomSeed);
    }
    app.loadingRemote = true;
    app.notify();
    try {
      final res = await pages.takeNext();
      if (!mounted || !identical(pages, _homePages) || res == null) return;
      app.remoteWorks = res.works;
      app.remoteError = null;
      app.loadingRemote = false;
      app.worksPage = 1;
      app.worksHasMore = res.hasMore && res.works.isNotEmpty;
      app.notify();
      if (mounted) setState(() {});
      if (app.worksHasMore) unawaited(pages.prefetch());
      _maybeRefill();
    } catch (e) {
      if (!mounted || !identical(pages, _homePages)) return;
      app.remoteError = e.toString();
      app.loadingRemote = false;
      app.notify();
    }
  }

  Future<void> _loadMore({bool retry = false}) async {
    final pages = _homePages;
    if (pages == null ||
        _homeAppending ||
        (_homeAppendError && !retry) ||
        !app.worksHasMore ||
        app.remoteWorks.isEmpty) {
      return;
    }
    _homeAppending = true;
    _homeAppendError = false;
    if (!pages.hasReadyPage) {
      app.worksLoadingMore = true;
      app.notify();
    }
    try {
      final page = await pages.takeNext();
      if (!mounted || !identical(pages, _homePages)) return;
      if (page == null || page.works.isEmpty) {
        app.worksHasMore = false;
      } else {
        app.worksPage++;
        app.remoteWorks.addAll(page.works);
        app.worksHasMore = page.hasMore;
      }
    } catch (_) {
      if (mounted && identical(pages, _homePages)) {
        setState(() => _homeAppendError = true);
      }
    } finally {
      if (mounted && identical(pages, _homePages)) {
        _homeAppending = false;
        app.worksLoadingMore = false;
        app.notify();
        if (app.worksHasMore && !_homeAppendError) {
          unawaited(pages.prefetch());
          _maybeRefill();
        }
      }
    }
  }

  /// 年龄分级是客户端过滤：过滤后不足一页时继续补拉（最多 10 页），直到凑够一页或拉完
  void _maybeRefill() {
    if (!app.hasAgeFilter &&
        (app.isDlsite || app.subtitleFilter != SubtitleFilter.all)) {
      return;
    }
    if (!app.worksHasMore || app.worksPage >= 10) return;
    if (_homeOrder.length >= 20) return;
    _loadMore();
  }

  List<int> get _homeOrder {
    final order = app.homeOrder;
    if (app.isDlsite || app.subtitleFilter != SubtitleFilter.all) return order;
    return order.where((i) => _hasAnySubtitle(app.homeList[i])).toList();
  }

  bool _hasAnySubtitle(Work work) {
    return work.hasSubtitle ||
        _localSubtitleWorkIds.contains(work.rj.toUpperCase());
  }

  @override
  void dispose() {
    _homePages?.close();
    _searchPages?.close();
    app.removeListener(_onAppChanged);
    LyricsLibraryService.instance.revision.removeListener(
      _onSubtitleLibraryChanged,
    );
    super.dispose();
  }

  String get serverLabel => app.isDlsite
      ? 'DLsite Play'
      : app.customServer
      ? (app.customSites.isNotEmpty
            ? app.customSites[app.customServerIdx].alias
            : context.l10n.homePageServerLabelText)
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
                      child: SubpageSwipe(
                        index: _categories.indexOf(app.category),
                        count: _categories.length,
                        onChanged: (index) =>
                            _changeCategory(_categories[index]),
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
          tooltip: app.sfwMode
              ? context.l10n.homePageHeaderTooltip
              : context.l10n.homePageHeaderTooltip2,
          icon: Icon(
            app.sfwMode
                ? Icons.family_restroom
                : Icons.family_restroom_outlined,
            size: 20,
            color: app.sfwMode ? p.accent : p.muted,
          ),
        ),
        Builder(
          // 深浅色按钮：圆形揭示从按钮中心扩散；Builder 的 context 即按钮本身
          builder: (buttonContext) => IconButton(
            onPressed: () =>
                Theme.of(buttonContext).brightness == Brightness.dark
                ? _setTheme(buttonContext, Brightness.light)
                : _setTheme(buttonContext, Brightness.dark),
            icon: Icon(
              Theme.of(buttonContext).brightness == Brightness.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              size: 20,
              color: p.muted,
            ),
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

  /// 从按钮中心向四周扩散到整个窗口
  void _setTheme(BuildContext buttonContext, Brightness b) {
    ThemeReveal.instance.fromWidget(
      buttonContext,
      b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void _clearSearchState() {
    // 让已经发出的搜索请求失效，避免清空后旧响应又把结果写回来。
    _searchPages?.close();
    _searchPages = null;
    _searchAppending = false;
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

  void _changeCategory(String category) {
    app.setCategory(category);
  }

  Widget _sortRow() {
    final labels = app.isDlsite
        ? {'all': context.l10n.all}
        : {
            'all': context.l10n.all,
            'hot': context.l10n.homePageLabelsLabels,
            'rec': context.l10n.homePageLabelsLabels2,
          };
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
                        onTap: () => _changeCategory(e.key),
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

  static Map<String, String> get sortLabels => {
    'collect': appL10n.homePageSortLabelsSortLabels2,
    'date': appL10n.favoritesPageReviewSortLabelsReviewSortLabels3,
    'myrating': appL10n.favoritesPageReviewSortLabelsReviewSortLabels4,
    'sales': appL10n.favoritesPageReviewSortLabelsReviewSortLabels2,
    'price': appL10n.homePageSortLabelsSortLabels3,
    'rating': appL10n.homePageSortLabelsSortLabels,
    'comments': appL10n.favoritesPageReviewSortLabelsReviewSortLabels,
    'rj': appL10n.blacklistPageTypeLabelsTypeLabels,
    'random': appL10n.homeRandomSort,
  };

  Map<String, String> get _availableSortLabels => app.isDlsite
      ? {
          'collect': switch (Localizations.localeOf(context)) {
            Locale(languageCode: 'zh', scriptCode: 'Hant') => '購買時間',
            Locale(languageCode: 'zh') => '购买时间',
            Locale(languageCode: 'ja') => '購入日',
            Locale(languageCode: 'ru') => 'Дата покупки',
            _ => 'Purchase date',
          },
          'date': sortLabels['date']!,
          'rj': sortLabels['rj']!,
          'random': sortLabels['random']!,
        }
      : sortLabels;

  Widget _sortDropdown() {
    return PopupMenuButton<String>(
      tooltip: context.l10n.favoritesPageReviewSortDropdownTooltip,
      // 悬停高亮跟随 child（MenuItem）的圆角，否则从圆角缺口漏出方形灰影
      borderRadius: BorderRadius.circular(11),
      onSelected: (v) {
        if (v == 'random' && app.sort == v) {
          _refreshRandom();
          return;
        }
        app.setSort(v);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: (ctx) => [
        _menuHead(context.l10n.favoritesPageReviewSortDropdownTooltip),
        ..._availableSortLabels.entries.map(
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
              (_availableSortLabels[app.sort] ??
                  _availableSortLabels.values.first),
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
    final random = app.sort == 'random';
    final ascending = !random && app.orderAsc;
    final button = GestureDetector(
      onTap: random ? _refreshRandom : () => app.setOrderAsc(!app.orderAsc),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: ascending ? p.accent : p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          random
              ? Icons.refresh
              : app.orderAsc
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          size: 16,
          color: ascending ? p.accent : p.muted,
        ),
      ),
    );
    return random
        ? Tooltip(message: context.l10n.refresh, child: button)
        : button;
  }

  void _refreshRandom() {
    if (_searchQuery.isNotEmpty) {
      _runSearch(_searchQuery);
    } else {
      _loadRemote();
    }
  }

  Widget _grid() {
    final order = _homeOrder;
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
                    if (_homeAppendError) {
                      _loadMore(retry: true);
                    } else if (app.remoteError != null && !app.loadingRemote) {
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
                    if (n.depth == 0 && n.metrics.extentAfter <= 240) {
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
                    context.l10n.loading,
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                )
              else if (_homeAppendError)
                TextButton(
                  onPressed: () => _loadMore(retry: true),
                  child: Text(context.l10n.retry),
                )
              else if (!app.worksHasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.l10n.homePageGridText,
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ),
            ],
          );
  }

  Widget _emptyHint() {
    final String msg;
    if (app.loadingRemote || app.worksLoadingMore) {
      msg = context.l10n.homePageEmptyHintText2;
    } else if (app.remoteError != null || _homeAppendError) {
      msg = context.l10n.homePageEmptyHintText5;
    } else if (app.hasAgeFilter || app.subOnly) {
      msg = context.l10n.homePageEmptyHintText4;
    } else {
      msg = context.l10n.homePageEmptyHintText;
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
              context.l10n.homePageEmptyHintText3,
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
      _clearSearchState();
      if (_homeFilterSig != _filterSig) _loadRemote();
      if (mounted) setState(() {});
      return;
    }
    if (!reset && (_searchAppending || !_searchHasMore)) return;
    if (reset) {
      if (_homeFilterSig != _filterSig) {
        _homePages?.close();
        _homePages = null;
        _homeFilterSig = '';
      }
      if (app.sort == 'random') {
        _searchRandomSeed = app.nextRandomSeed(_searchRandomSeed);
      }
      final seed = _searchRandomSeed;
      _searchPages?.close();
      _searchPages = WorksPageBuffer(
        (page) =>
            ApiService.searchWorks(app, query, page: page, randomSeed: seed),
      );
      setState(() {
        _searchQuery = query;
        _searchResults.clear();
        _searchPage = 0;
        _searchHasMore = true;
      });
    }
    final pages = _searchPages;
    if (pages == null) return;
    _searchAppending = true;
    _searchError = false;
    if (!pages.hasReadyPage) setState(() => _searchLoading = true);
    try {
      final list = await pages.takeNext();
      if (!mounted || !identical(pages, _searchPages)) return;
      setState(() {
        if (list != null) {
          _searchResults.addAll(list.works);
          _searchPage++;
        }
        _searchHasMore = list != null && list.hasMore && list.works.isNotEmpty;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted || !identical(pages, _searchPages)) return;
      setState(() {
        _searchLoading = false;
        _searchError = true;
      });
    } finally {
      if (identical(pages, _searchPages)) _searchAppending = false;
    }
    if (!_searchError && _searchHasMore) unawaited(pages.prefetch());
    _maybeRefillSearch();
  }

  void _maybeRefillSearch() {
    // 年龄/全部字幕是客户端过滤：结果不足一页时继续补拉（最多 4 页）
    if (_searchQuery.isNotEmpty &&
        (app.hasAgeFilter ||
            (!app.isDlsite && app.subtitleFilter == SubtitleFilter.all)) &&
        _searchHasMore &&
        !_searchAppending &&
        !_searchError &&
        _searchPage < 4 &&
        _visibleSearchResults.length < 20) {
      _runSearch(_searchQuery, reset: false);
    }
  }

  List<Work> get _visibleSearchResults {
    var res = _searchResults.where((w) => !app.isBlacklistedWork(w)).toList();
    if (app.hasAgeFilter) {
      res = res.where((w) => app.ageFilters.contains(w.age.index)).toList();
    }
    if (!app.isDlsite && app.subtitleFilter == SubtitleFilter.all) {
      res = res.where(_hasAnySubtitle).toList();
    }
    return res;
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
            Text(
              context.l10n.homePageSearchResultsViewText,
              style: TextStyle(fontSize: 13, color: p.dim),
            ),
          ],
        ),
      );
    }
    final res = _visibleSearchResults;
    if (_searchError && res.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_searchLoading) {
            _runSearch(_searchQuery, reset: _searchPage == 0);
          }
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 34, color: p.dim),
              const SizedBox(height: 10),
              Text(
                context.l10n.homePageEmptyHintText5,
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
    if (res.isEmpty) {
      return Center(
        child: Text(
          context.l10n.homePageSearchResultsViewText2,
          style: TextStyle(fontSize: 13, color: p.dim),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (!_searchError &&
                  n.depth == 0 &&
                  n.metrics.extentAfter <= 240) {
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
            child: Text(
              context.l10n.loading,
              style: TextStyle(fontSize: 12, color: p.dim),
            ),
          )
        else if (_searchError)
          TextButton(
            onPressed: () => _runSearch(_searchQuery, reset: false),
            child: Text(context.l10n.retry),
          )
        else if (!_searchHasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              context.l10n.homePageSearchResultsViewText3,
              style: TextStyle(fontSize: 12, color: p.dim),
            ),
          ),
      ],
    );
  }
}
