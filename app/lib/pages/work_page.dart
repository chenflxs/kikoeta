import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/dictation_media_matcher.dart';
import '../services/media_selection.dart';
import '../services/media_tree.dart';
import '../services/works_page_buffer.dart';
import '../smooth_scroll.dart';
import '../src/rust/api/kikoeru_api.dart';
import '../src/rust/api/textcodec.dart';
import '../src/rust/api/translate.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/media_tree_sliver.dart';
import '../widgets/playlist_picker.dart';
import 'dictation_translation_page.dart';
import '../l10n/strings.dart';

/// 播放标记的接口值与中文标签。
Map<String, String> get workProgressLabels => <String, String>{
  'marked': appL10n.wantToListen,
  'listening': appL10n.listening,
  'listened': appL10n.listened,
  'replay': appL10n.replay,
  'postponed': appL10n.postponed,
};

class WorkPage extends StatefulWidget {
  final AppState app;
  final Work work;
  final VoiceDownload? downloadItem;
  const WorkPage({
    super.key,
    required this.app,
    required this.work,
    this.downloadItem,
  });

  @override
  State<WorkPage> createState() => _WorkPageState();
}

/// 单颗评分星：灰底上按 [fill]（0~1）比例叠一层彩色星。
class _StarButton extends StatelessWidget {
  final double fill;
  final Color color;
  final VoidCallback onTap;

  const _StarButton({
    required this.fill,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: SizedBox(
          width: 18,
          height: 18,
          child: Stack(
            children: [
              Icon(Icons.star, size: 17, color: p.dim),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: Icon(Icons.star, size: 17, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 评分星行：用一个动画控制器把「填充值 + 颜色」从当前状态连续过渡到
/// 新状态（首次加载从 0 填充），避免多段动画叠加造成中途停止或跳变。
/// 已打分时额外显示一颗黄星表示平均分。
class _RatingStars extends StatefulWidget {
  final double value;
  final bool rated;
  final String text;
  final Color activeColor;
  final ValueChanged<int> onRate;
  final VoidCallback onClear;

  const _RatingStars({
    required this.value,
    required this.rated,
    required this.text,
    required this.activeColor,
    required this.onRate,
    required this.onClear,
  });

  @override
  State<_RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<_RatingStars>
    with SingleTickerProviderStateMixin {
  static const _yellow = Color(0xFFF5B301);
  static const _curve = Curves.easeOutCubic;

  late final AnimationController _controller;
  double _fromValue = 0;
  double _toValue = 0;
  Color _fromColor = _yellow;
  Color _toColor = _yellow;

  Color get _targetColor => widget.rated ? widget.activeColor : _yellow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _toValue = widget.value;
    _toColor = _targetColor;
    _fromColor = _toColor;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _RatingStars oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetColor = _targetColor;
    if (widget.value == _toValue && targetColor == _toColor) return;
    final t = _curve.transform(_controller.value);
    _fromValue = _fromValue + (_toValue - _fromValue) * t;
    _fromColor = Color.lerp(_fromColor, _toColor, t)!;
    _toValue = widget.value;
    _toColor = targetColor;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _curve.transform(_controller.value);
        final value = _fromValue + (_toValue - _fromValue) * t;
        final color = Color.lerp(_fromColor, _toColor, t)!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              _StarButton(
                fill: (value - i).clamp(0.0, 1.0),
                color: color,
                // 已打分时再次点击自己打的那个分值 = 取消打分。
                onTap: widget.rated && widget.value == i + 1
                    ? widget.onClear
                    : () => widget.onRate(i + 1),
              ),
            const SizedBox(width: 6),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: _curve,
              child: widget.rated
                  ? const Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(Icons.star, size: 14, color: _yellow),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(widget.text, style: TextStyle(fontSize: 12, color: p.muted)),
          ],
        );
      },
    );
  }
}

class _WorkMenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _WorkMenuEntry({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _WorkPageState extends State<WorkPage> {
  static const _textEncodings = [
    'UTF-8',
    'UTF-16LE',
    'UTF-16BE',
    'GBK',
    'GB18030',
    'Big5',
    'Shift_JIS',
    'EUC-JP',
    'ISO-2022-JP',
    'Windows-1252',
  ];

  AppState get app => widget.app;
  Work get work => widget.work;
  VoiceDownload? get downloadItem => widget.downloadItem;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  List<MediaNode>? _tree;
  MediaTreeIndex? _treeIndex;
  MediaTreeIndex? _mediaOnlyIndex;
  MediaTreeIndex? _visibleIndex;
  List<MediaTreeRow> _visibleRows = const [];
  bool _rowsDirty = true;
  bool _tracksFailed = false;
  bool _dictationOpening = false;
  final MediaSelection _selection = MediaSelection();
  final Set<String> _expanded = {};
  // 复选框滑动选中：按下后拖动，划过的区间成片切换，缩回复原。
  bool _dragSelectValue = true;
  Set<String>? _dragBasePaths;
  int? _dragAnchorRow;
  int? _dragLastRow;
  bool _mouseDragPending = false;
  MediaNode? _mouseDownNode;
  Offset _mouseDownPosition = Offset.zero;
  Offset? _lastDragPosition;
  Timer? _autoScrollTimer;
  final Map<String, GlobalKey> _rowKeys = {};
  List<String>? _smartTarget; // 智能路径自动进入的目录（标题链），用于「查看全部文件」
  late int _seenLoginEpoch;
  bool _translating = false;
  List<LanguageEdition> _languageEditions = const [];
  bool _openingLanguageEdition = false;
  double _ratingAverage = 0;
  double? _userRating;
  String? _myProgress;
  String? _myReviewText;
  List<Work> _similarWorks = const [];
  WorksPageBuffer? _similarPages;
  int _similarTotal = 0;
  bool _similarHasMore = true;
  bool _similarAppending = false;
  bool _similarLoading = false;
  bool _similarAppendError = false;
  late (int, int, bool) _seenSimilarScope;
  final ScrollController _pageScroll = ScrollController();

  (int, int, bool) get _similarScope =>
      (app.serverEpoch, app.loginEpoch, app.sfwMode);

  @override
  void initState() {
    super.initState();
    _seenLoginEpoch = app.loginEpoch;
    _seenSimilarScope = _similarScope;
    _languageEditions = work.languageEditions;
    if (downloadItem != null) {
      _tree = ApiService.sortedMediaNodes(downloadItem!.tree);
      _tracksFailed = false;
      _applyDownloadSmartPath();
    }
    app.addListener(_onAppChanged);
    _pageScroll.addListener(_onPageScroll);
    if (downloadItem == null) _loadTracks();
    _ratingAverage = work.rating;
    _loadWorkDetails();
    if (!app.isDlsite) _loadSimilarWorks();
  }

  @override
  void dispose() {
    _similarPages?.close();
    _stopAutoScrollTimer();
    app.removeListener(_onAppChanged);
    _pageScroll.dispose();
    super.dispose();
  }

  void _onAppChanged() {
    if (downloadItem == null && app.loginEpoch != _seenLoginEpoch) {
      _seenLoginEpoch = app.loginEpoch;
      _loadTracks();
    }
    final scope = _similarScope;
    if (scope != _seenSimilarScope) {
      _seenSimilarScope = scope;
      _loadSimilarWorks(clear: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadSimilarWorks({
    bool reset = true,
    bool clear = false,
  }) async {
    if (!reset && (_similarAppending || !_similarHasMore)) return;
    if (reset) {
      _similarPages?.close();
      if (work.apiId == null || app.customServer || app.isDlsite) {
        _similarPages = null;
        _similarAppending = false;
        setState(() {
          _similarWorks = const [];
          _similarHasMore = false;
          _similarLoading = false;
        });
        return;
      }
      _similarPages = WorksPageBuffer(
        (page) => ApiService.fetchSimilarWorks(app, work, page: page),
      );
      if (clear) {
        setState(() {
          _similarWorks = const [];
          _similarTotal = 0;
        });
      }
    }
    final pages = _similarPages;
    if (pages == null) return;
    _similarAppending = true;
    _similarAppendError = false;
    try {
      final previous = reset ? const <Work>[] : _similarWorks;
      final seen = {for (final w in previous) w.rj};
      final added = <Work>[];
      WorksPage? result;
      do {
        if (!pages.hasReadyPage && !_similarLoading) {
          setState(() => _similarLoading = true);
        }
        result = await pages.takeNext();
        if (!mounted || !identical(pages, _similarPages)) return;
        if (result == null) break;
        final visible = ApiService.filterSimilarWorks(
          result.works,
          current: work,
          sfwMode: app.sfwMode,
          isBlacklisted: app.isBlacklistedWork,
        );
        added.addAll(visible.where((w) => seen.add(w.rj)));
        // Filtered or duplicate-only pages do not extend the scrollable list.
      } while (added.isEmpty && result.hasMore);
      setState(() {
        _similarLoading = false;
        if (result != null) _similarTotal = result.totalCount;
        _similarHasMore = result?.hasMore ?? false;
        _similarWorks = [...previous, ...added];
      });
      if (_similarHasMore) unawaited(pages.prefetch());
    } catch (_) {
      if (!mounted || !identical(pages, _similarPages)) return;
      setState(() {
        _similarLoading = false;
        if (reset) _similarHasMore = false;
        _similarAppendError = !reset;
      });
    } finally {
      if (identical(pages, _similarPages)) _similarAppending = false;
    }
  }

  Future<void> _loadTracks({bool forceRefresh = false}) async {
    final id = work.apiId;
    if (id == null) return;
    try {
      final t = await ApiService.fetchTracks(
        app,
        id,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _tree = t;
          _tracksFailed = false;
          _applySmartPath();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tracksFailed = true);
    }
  }

  MediaTreeIndex _indexForTree() {
    final tree = _tree ?? const <MediaNode>[];
    if (!identical(_treeIndex?.roots, tree)) {
      _treeIndex = MediaTreeIndex(tree);
      _mediaOnlyIndex = null;
      _rowsDirty = true;
      _selection.bindTree(tree);
    }
    return _treeIndex!;
  }

  MediaTreeIndex _indexForVisibleTree() {
    final full = _indexForTree();
    final index = app.mediaFilesOnly
        ? (_mediaOnlyIndex ??= MediaTreeIndex(_mediaOnlyTree(full.roots)))
        : full;
    if (!identical(_visibleIndex, index)) {
      _visibleIndex = index;
      _rowsDirty = true;
    }
    if (_rowsDirty) {
      _visibleRows = index.visibleRows(_expanded);
      _rowsDirty = false;
    }
    return index;
  }

  void _applyDownloadSmartPath() {
    final tree = _tree;
    final item = downloadItem;
    if (tree == null || item == null || tree.isEmpty) return;
    _smartTarget = null;
    _expanded.clear();
    _rowsDirty = true;
    var current = tree;
    while (current.length == 1 && current.first.isDir) {
      _expanded.add(current.first.path);
      current = current.first.children;
    }
    final index = MediaTreeIndex(current);
    final manager = DownloadManager.instance;
    final counts = <int, int>{};
    for (final row in index.rows) {
      if (!row.node.isDir &&
          row.parentIndex != null &&
          manager.isDownloaded(item, row.node)) {
        counts.update(
          row.parentIndex!,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    MediaTreeRow? best;
    var count = 0;
    for (final row in index.rows) {
      final local = counts[row.index] ?? 0;
      // Match the former depth-first, postorder tie preference.
      if (local > count ||
          (local > 0 &&
              local == count &&
              best != null &&
              (row.subtreeEnd < best.subtreeEnd ||
                  (row.subtreeEnd == best.subtreeEnd &&
                      row.depth > best.depth)))) {
        count = local;
        best = row;
      }
    }
    while (best != null) {
      _expanded.add(best.node.path);
      best = best.parentIndex == null ? null : index.rows[best.parentIndex!];
    }
  }

  Future<void> _loadWorkDetails() async {
    final id = work.apiId;
    if (id == null) return;
    final epoch = app.serverEpoch;
    final favoriteVersion = app.favVersion;
    final previousProgress = _myProgress;
    try {
      final details = await ApiService.fetchWork(app, id);
      if (!mounted || app.serverEpoch != epoch) return;
      if (details.hasReview != null &&
          (!app.isDlsite || app.favVersion == favoriteVersion)) {
        app.syncFavoriteFromServer(work, details.hasReview!);
      }
      if (mounted) {
        setState(() {
          _languageEditions = app.isDlsite
              ? const []
              : details.languageEditions;
          _ratingAverage = details.rating;
          _userRating = details.userRating;
          if (!app.isDlsite || _myProgress == previousProgress) {
            _myProgress = details.progress;
          }
          _myReviewText = details.reviewText;
        });
      }
    } catch (_) {
      // 作品仍可正常浏览；评分/多语言入口仅在详情接口可用时显示。
    }
  }

  String get _ratingText =>
      _ratingAverage <= 0 ? '--' : _ratingAverage.toStringAsFixed(1);

  /// 作品评分：未打分时黄色五角星按平均分比例填充，右侧展示平均分；
  /// 打分后变为蓝色五角星 + 一颗黄星和平均分。填充/变色由同一个
  /// 控制器从当前状态连续过渡，不会出现中途重启或跳变。
  Widget _ratingStars() {
    return _RatingStars(
      value: (_userRating ?? _ratingAverage).clamp(0.0, 5.0),
      rated: _userRating != null,
      text: _ratingText,
      activeColor: p.accent,
      onRate: (stars) => _rateWork(stars.toDouble()),
      onClear: _clearRating,
    );
  }

  Future<void> _rateWork(double value) async {
    final l10n = context.l10n;
    if (work.apiId == null) return;
    final previous = _userRating;
    setState(() => _userRating = value);
    try {
      await ApiService.submitReview(
        app,
        work,
        rating: value,
        reviewText: _myReviewText,
        progress: _myProgress,
      );
      unawaited(_refreshRatingAverage());
    } catch (e) {
      if (!mounted) return;
      setState(() => _userRating = previous);
      _toast(l10n.workPageRateWorkToast((e).toString()));
    }
  }

  Future<void> _clearRating() async {
    final l10n = context.l10n;
    if (work.apiId == null) return;
    final previous = _userRating;
    setState(() => _userRating = null);
    try {
      await ApiService.clearReviewRating(app, work);
      unawaited(_refreshRatingAverage());
    } catch (e) {
      if (!mounted) return;
      setState(() => _userRating = previous);
      _toast(l10n.workPageClearRatingToast((e).toString()));
    }
  }

  /// 只刷新平均分，避免覆盖用户刚点下的本人评分。
  Future<void> _refreshRatingAverage() async {
    final id = work.apiId;
    if (id == null) return;
    try {
      final details = await ApiService.fetchWork(app, id);
      if (mounted) setState(() => _ratingAverage = details.rating);
    } catch (_) {
      // 平均分刷新失败不影响当前展示。
    }
  }

  /// 更新播放标记；再次选择当前标记时取消标记（progress=null）。
  Future<void> _setProgress(String progress) async {
    final l10n = context.l10n;
    if (work.apiId == null) return;
    final previous = _myProgress;
    if (app.isDlsite && previous == progress) return;
    final clearing = previous == progress;
    setState(() => _myProgress = clearing ? null : progress);
    try {
      if (clearing && !app.isDlsite) {
        await ApiService.clearReviewProgress(app, work);
      } else {
        await ApiService.submitReview(app, work, progress: progress);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _myProgress = previous);
      _toast(
        clearing
            ? l10n.workPageSetProgressToast2((e).toString())
            : l10n.workPageSetProgressToast((e).toString()),
      );
    }
  }

  /// AppBar 标记按钮：未标记显示空心书签 + “标记”，已标记显示实心书签
  /// + 对应状态文字并变蓝；点击展开五种播放标记。
  Widget _markButton() {
    final marked = _myProgress != null;
    final color = marked ? p.accent : p.text;
    final progressLabels = app.isDlsite
        ? <String, String>{
            'listened': _dlsiteProgressLabel('listened'),
            'unwatched': _dlsiteProgressLabel('unwatched'),
            'hidden': _dlsiteProgressLabel('hidden'),
          }
        : workProgressLabels;
    return PopupMenuButton<String>(
      tooltip: context.l10n.mark,
      onSelected: _setProgress,
      itemBuilder: (_) => [
        for (final entry in progressLabels.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  _myProgress == entry.key
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 17,
                  color: _myProgress == entry.key ? p.accent : p.muted,
                ),
                const SizedBox(width: 10),
                Text(entry.value),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              marked ? Icons.bookmark : Icons.bookmark_border,
              size: 19,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              marked
                  ? (progressLabels[_myProgress] ?? context.l10n.mark)
                  : context.l10n.mark,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _dlsiteProgressLabel(String progress) {
    final locale = Localizations.localeOf(context);
    final language = locale.scriptCode == 'Hant'
        ? 'zh-Hant'
        : locale.languageCode;
    return switch ((language, progress)) {
      ('ja', 'listened') => '視聴済み',
      ('ja', 'unwatched') => '未視聴',
      ('ja', 'hidden') => '非表示',
      ('zh', 'listened') => '已观看',
      ('zh', 'unwatched') => '未观看',
      ('zh', 'hidden') => '不显示',
      ('zh-Hant', 'listened') => '已觀看',
      ('zh-Hant', 'unwatched') => '未觀看',
      ('zh-Hant', 'hidden') => '不顯示',
      ('ru', 'listened') => 'Прослушано',
      ('ru', 'unwatched') => 'Не прослушано',
      ('ru', 'hidden') => 'Скрыто',
      (_, 'listened') => 'Watched',
      (_, 'unwatched') => 'Unwatched',
      _ => 'Hidden',
    };
  }

  Future<void> _openReviewDialog() async {
    if (app.isDlsite) return;
    final l10n = context.l10n;
    if (work.apiId == null) {
      _toast(l10n.workPageOpenReviewDialogToast);
      return;
    }
    final result = await showDialog<_ReviewResult>(
      context: context,
      builder: (_) => _ReviewDialog(
        app: app,
        work: work,
        userRating: _userRating,
        progress: _myProgress,
        reviewText: _myReviewText,
      ),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      setState(() {
        _userRating = null;
        _myProgress = null;
        _myReviewText = null;
      });
    } else {
      setState(() {
        _myProgress = result.progress;
        _myReviewText = result.reviewText;
      });
    }
    // 重新拉取详情，让平均分与当前账号状态和服务端保持一致。
    unawaited(_loadWorkDetails());
  }

  Future<void> _editPlaylistMembership() async {
    final l10n = context.l10n;
    if (work.apiId == null) {
      _toast(l10n.workPageAddToServerPlaylistToast2);
      return;
    }
    await showWorkPlaylistMembership(context, app: app, work: work);
  }

  Future<void> _openLanguageEdition(LanguageEdition edition) async {
    final l10n = context.l10n;
    if (_openingLanguageEdition) return;
    setState(() => _openingLanguageEdition = true);
    try {
      final target = await ApiService.fetchWork(app, edition.id);
      if (!mounted) return;
      if (app.sfwMode && target.age != Age.all) {
        _toast(l10n.workPageOpenLanguageEditionToast2);
        return;
      }
      await Navigator.of(context).push(buildWorkRoute(app, target));
    } catch (_) {
      if (mounted) _toast(l10n.workPageOpenLanguageEditionToast);
    } finally {
      if (mounted) setState(() => _openingLanguageEdition = false);
    }
  }

  void _showLanguageEditions() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: context.l10n.close,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              Flexible(
                child: SmoothListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _languageEditions.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: p.line),
                  itemBuilder: (_, index) {
                    final edition = _languageEditions[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _openLanguageEdition(edition);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Text(
                          edition.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.text),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 智能路径（对齐 asmr.one Auto initial path） ----------

  /// 树加载完成后应用智能路径：展开到最佳目录并记录目标（供「查看全部文件」）
  void _applySmartPath() {
    _rowsDirty = true;
    _smartTarget = null;
    if (app.initialPathBehavior != 'auto') return;
    final t = _tree;
    if (t == null || t.isEmpty) return;
    final target = _smartInitialPath();
    if (target.isEmpty) return;
    // 展开目标目录的整条祖先链（含唯一子文件夹自动下沉）
    _expanded.clear();
    var cur = t;
    for (final part in target) {
      final node = cur.where((n) => n.isDir && n.title == part).firstOrNull;
      if (node == null) break;
      _expanded.add(node.path);
      cur = node.children;
    }
    _smartTarget = List.of(target);
  }

  /// 回根目录（「查看全部文件」）
  void _showAllFiles() {
    setState(() {
      _smartTarget = null;
      _expanded.clear();
      _rowsDirty = true;
    });
  }

  /// 计算智能路径：返回要进入的目录标题链（空 = 根目录）
  List<String> _smartInitialPath() {
    final tree = _tree ?? [];
    // 1) 沿「唯一子文件夹」链一路下沉
    var cur = List<MediaNode>.from(tree);
    final path = <String>[];
    while (cur.length == 1 && cur[0].isDir) {
      path.add(cur[0].title);
      if (cur[0].children.isEmpty) break;
      cur = cur[0].children;
    }
    if (app.initialPathBehavior != 'auto' || tree.isEmpty) return path;

    // 2) 按迭代索引统计音频，目录路径只在首次遇到时构建。
    final stats = <_DirStat>[];
    final byPath = <String, _DirStat>{};
    final folderPaths = <int?, List<String>>{null: path};
    final index = MediaTreeIndex(cur);
    for (final row in index.rows) {
      final n = row.node;
      if (!_isAudio(n) || n.url == null || n.url!.isEmpty) continue;
      final folderPath = folderPaths.putIfAbsent(row.parentIndex, () {
        final titles = <String>[];
        var parent = row.parentIndex;
        while (parent != null) {
          final folder = index.rows[parent];
          titles.add(folder.node.title);
          parent = folder.parentIndex;
        }
        return [...path, ...titles.reversed];
      });
      final key = folderPath.join('/');
      final hit = byPath[key];
      if (hit != null) {
        hit.duration += n.duration;
        final ext = _ext(n.title);
        hit.byExt[ext] = (hit.byExt[ext] ?? 0) + 1;
      } else {
        final stat = _DirStat(
          path: List.of(folderPath),
          duration: n.duration,
          byExt: {_ext(n.title): 1},
          se: _notNoSe(key),
        );
        byPath[key] = stat;
        stats.add(stat);
      }
    }
    // 3) 过滤附带/杂谈类目录
    const excludeWords = ['おまけ', '特典', '附赠', '杂谈', 'freetalk'];
    stats.removeWhere(
      (x) => excludeWords.any((w) => x.path.join('/').contains(w)),
    );

    if (stats.isEmpty || stats.length > 6) return path;

    // 4) 时长最长 → 300 秒容差
    stats.sort((a, b) => b.duration - a.duration);
    var chosen = stats.first;
    final candidates = stats
        .where((x) => x.duration >= chosen.duration - 300)
        .toList();

    // 5) 效果音偏好过滤
    final seMatched = candidates
        .where((x) => x.se == app.sePreference)
        .toList();
    if (seMatched.isNotEmpty) {
      // 6) 按音频类型偏好顺序 + 文件数排序
      final byType = <_DirStat>[];
      for (final t in app.audioTypePreference) {
        final list = seMatched.where((x) => (x.byExt[t] ?? 0) > 0).toList()
          ..sort((a, b) => (b.byExt[t] ?? 0) - (a.byExt[t] ?? 0));
        byType.addAll(list);
      }
      if (byType.isNotEmpty) chosen = byType.first;
    }
    return chosen.path;
  }

  /// 提取小写扩展名；无扩展名返回空串
  String _ext(String name) {
    final t = name.split('.').last.toLowerCase();
    return t == name.toLowerCase() ? '' : t;
  }

  /// 路径同时含「无/カット/no/cut…」与「se/效果音/音效/効果音…」→ 判为无效果音目录
  bool _notNoSe(String path) {
    const noWords = ['no', 'cut', '无', '無', 'なし', 'less', 'カット'];
    const seWords = ['se', '效果音', '音效', '効果音'];
    final lower = path.toLowerCase();
    return !noWords.any(
      (w) => lower.contains(w) && seWords.any((s) => lower.contains(s)),
    );
  }

  bool _isAudio(MediaNode n) =>
      !n.isDir &&
      n.title.toLowerCase().contains(
        RegExp(r'\.(mp3|ogg|opus|wav|aac|flac|webm|mp4|m4a|mka|aiff|wma|ape)$'),
      );

  List<MediaNode> _collectAudio(Iterable<MediaNode> nodes) =>
      MediaTreeIndex(nodes.toList()).files.where(_isAudio).toList();

  List<MediaNode> _collectDictationMedia(Iterable<MediaNode> nodes) =>
      MediaTreeIndex(nodes.toList()).files.where(_isMediaFile).toList();
  void _playFiles(Iterable<MediaNode> files, {MediaNode? selected}) {
    if (app.sfwMode && work.age != Age.all) {
      _toast(context.l10n.workPagePlayAsAudioToast);
      return;
    }
    final selectedExt = selected == null ? null : _ext(selected.title);
    final audio = _collectAudio(files)
        .where((item) => selectedExt == null || _ext(item.title) == selectedExt)
        .toList();
    if (audio.isEmpty) {
      _toast(context.l10n.workPagePlayFilesToast);
      return;
    }
    final selectedIndex = selected == null
        ? 0
        : audio.indexWhere((item) => item.path == selected.path);
    app.startPlayback(
      work,
      audio,
      initialTrackIndex: selectedIndex < 0 ? 0 : selectedIndex,
    );
    Navigator.of(context).pushNamed('/player');
  }

  void _playAsAudio(MediaNode n) {
    if (app.sfwMode && work.age != Age.all) {
      _toast(context.l10n.workPagePlayAsAudioToast);
      return;
    }
    app.startPlayback(work, [n]);
    Navigator.of(context).pushNamed('/player');
  }

  Future<void> _downloadSelected() async {
    final l10n = context.l10n;
    final tree = _tree;
    if (tree == null) {
      _toast(l10n.workPageDownloadSelectedToast2);
      return;
    }
    final selected = Set<String>.of(_selection.projects);
    if (selected.isEmpty) {
      _toast(l10n.workPageDownloadSelectedToast4);
      return;
    }
    try {
      await DownloadManager.instance.enqueue(
        app: app,
        work: work,
        tree: tree,
        selectedPaths: selected,
      );
      if (mounted) _toast(l10n.workPageDownloadSelectedToast);
    } catch (e) {
      if (mounted) _toast(l10n.workPageDownloadSelectedToast3((e).toString()));
    }
  }

  Future<void> _copyRj() async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: work.rj));
    if (mounted) _toast(l10n.workPageCopyRjToast((work.rj).toString()));
  }

  bool _isImage(MediaNode n) => n.title.toLowerCase().contains(
    RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp|avif)$'),
  );

  bool _isText(MediaNode n) => n.title.toLowerCase().contains(
    RegExp(r'\.(txt|lrc|srt|json|md|log|vtt)$'),
  );

  bool _isVideo(MediaNode n) => n.title.toLowerCase().contains(
    RegExp(r'\.(mp4|mkv|webm|avi|mov|wmv|flv|ts|m4v)$'),
  );

  bool _isMediaFile(MediaNode n) => _isAudio(n) || _isVideo(n);

  List<MediaNode> _mediaOnlyTree(List<MediaNode> nodes) {
    final index = MediaTreeIndex(nodes);
    final copies = <int, MediaNode>{};
    for (final row in index.rows.reversed) {
      final node = row.node;
      if (!node.isDir) {
        if (_isMediaFile(node)) copies[row.index] = node;
        continue;
      }
      final children = <MediaNode>[];
      for (
        var child = row.index + 1;
        child < row.subtreeEnd;
        child = index.rows[child].subtreeEnd
      ) {
        final copy = copies[child];
        if (copy != null) children.add(copy);
      }
      if (children.isNotEmpty) {
        copies[row.index] = MediaNode(
          title: node.title,
          type: node.type,
          path: node.path,
          children: children,
          url: node.url,
          downloadUrl: node.downloadUrl,
          duration: node.duration,
        );
      }
    }
    return [
      for (final row in index.rows)
        if (row.parentIndex == null && copies.containsKey(row.index))
          copies[row.index]!,
    ];
  }

  Future<void> _refreshWork() async {
    final l10n = context.l10n;
    if (downloadItem != null) {
      setState(() {
        _tree = ApiService.sortedMediaNodes(downloadItem!.tree);
        _tracksFailed = false;
        _applyDownloadSmartPath();
      });
      _toast(l10n.workPageRefreshWorkToast3);
      return;
    }
    await Future.wait([
      _loadTracks(forceRefresh: true),
      _loadWorkDetails(),
      _loadSimilarWorks(),
    ]);
    if (mounted) {
      _toast(
        _tracksFailed
            ? l10n.workPageRefreshWorkToast2
            : l10n.workPageRefreshWorkToast,
      );
    }
  }

  Future<void> _openExternalWork(String url) async {
    final l10n = context.l10n;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) _toast(l10n.settingsPageOpenRepoToast);
  }

  Future<void> _deleteSelectedLocalFiles() async {
    final l10n = context.l10n;
    final item = downloadItem;
    final selected = Set<String>.of(_selection.projects);
    if (item == null || selected.isEmpty) {
      _toast(l10n.workPageDeleteSelectedLocalFilesToast2);
      return;
    }
    final deleted = await DownloadManager.instance.deleteDownloadedFiles(
      item,
      selected,
    );
    if (!mounted) return;
    if (deleted == 0) {
      _toast(l10n.workPageDeleteSelectedLocalFilesToast);
      return;
    }
    setState(() => _selection.clear());
    _toast(l10n.workPageDeleteSelectedLocalFilesToast3((deleted).toString()));
  }

  Future<void> _confirmDeleteWork() async {
    final l10n = context.l10n;
    final item = downloadItem;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.workPageConfirmedText2),
        content: Text(
          l10n.workPageConfirmedText4((item.work.title).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DownloadManager.instance.deleteWorks({item.id});
    if (!mounted) return;
    if (DownloadManager.instance.downloads.any(
      (entry) => entry.id == item.id,
    )) {
      _toast(l10n.workPageConfirmDeleteWorkToast);
      return;
    }
    Navigator.of(context).pop();
  }

  void _onDeleteWorkLongPress() {
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero, _confirmDeleteWork);
  }

  Future<void> _onMoreAction(String action) async {
    final l10n = context.l10n;
    switch (action) {
      case 'deleteLocal':
        await _deleteSelectedLocalFiles();
        return;
      case 'refresh':
        await _refreshWork();
        return;
      case 'review':
        await _openReviewDialog();
        return;
      case 'addToPlaylist':
        await _editPlaylistMembership();
        return;
      case 'dictationTranslation':
        if (_dictationOpening) return;
        final tree = _tree;
        if (tree == null) {
          _toast(
            _tracksFailed
                ? l10n.workPageOnMoreActionToast2
                : l10n.workPageOnMoreActionToast,
          );
          return;
        }
        final automatic = _selection.paths.isEmpty;
        _dictationOpening = true;
        try {
          final tracks = automatic
              ? await DictationMediaMatcher.selectForDictation(_indexForTree())
              : _collectDictationMedia(tree)
                    .where(
                      (track) =>
                          _selection.paths.contains(track.path) &&
                          ((track.downloadUrl?.isNotEmpty ?? false) ||
                              (track.url?.isNotEmpty ?? false)),
                    )
                    .toList();
          if (!mounted) return;
          if (tracks.isEmpty) {
            _toast(l10n.workPageOnMoreActionToast4);
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DictationTranslationPage(
                app: app,
                work: work,
                tracks: tracks,
                automaticallyMatched: automatic,
              ),
            ),
          );
        } finally {
          _dictationOpening = false;
        }
        return;
      case 'asmr':
        await _openExternalWork('https://asmr.one/work/${work.rj}');
        return;
      case 'dlsite':
        await _openExternalWork(
          'https://www.dlsite.com/maniax/work/=/product_id/${work.rj}.html',
        );
        return;
      case 'mediaOnly':
        app.setMediaFilesOnly(!app.mediaFilesOnly);
        return;
    }
  }

  void _openFile(MediaNode n, List<MediaNode> siblings) {
    if (_isImage(n)) {
      _previewImages(n, siblings);
    } else if (_isText(n)) {
      _showTextViewer(n);
    } else if (_isVideo(n)) {
      _openVideoChooser(n);
    } else {
      _toast(context.l10n.workPageOpenFileToast((n.title).toString()));
    }
  }

  /// 图片预览：只收集同一路径（同一层）下的图片，左右滑动或点两侧按钮切换
  void _previewImages(MediaNode current, List<MediaNode> siblings) {
    final images = [
      for (final node in siblings)
        if (!node.isDir && _isImage(node) && (node.url?.isNotEmpty ?? false))
          node,
    ];
    final start = images.indexWhere((node) => identical(node, current));
    if (start < 0) {
      _toast(context.l10n.playerPageOpenCurrentToast);
      return;
    }
    _openPreview([for (final node in images) node.url!], start);
  }

  void _openPreview(List<String> urls, int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _ImagePreviewDialog(urls: urls, initialIndex: index),
    );
  }

  Future<void> _showTextViewer(MediaNode n) async {
    final l10n = context.l10n;
    if (n.url == null) {
      _toast(l10n.playerPageOpenCurrentToast);
      return;
    }
    final bytes = await apiGetBytes(url: n.url!);
    String text;
    String encoding;
    try {
      final r = apiDecodeText(bytes: bytes, encoding: '');
      text = r.text;
      encoding = r.encoding;
    } catch (e) {
      text = utf8.decode(bytes, allowMalformed: true);
      encoding = 'UTF-8';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 600,
          height: 500,
          child: StatefulBuilder(
            builder: (ctx2, setState) {
              void applyEncoding(String enc) {
                try {
                  final r = apiDecodeText(bytes: bytes, encoding: enc);
                  setState(() {
                    encoding = r.encoding;
                    text = r.text;
                  });
                } catch (e) {
                  _toast(l10n.workPageApplyEncodingToast((e).toString()));
                }
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          initialValue: encoding,
                          tooltip: l10n.workPageShowTextViewerTooltip,
                          onSelected: applyEncoding,
                          itemBuilder: (_) => _textEncodings.map((e) {
                            final active = e == encoding;
                            return PopupMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Icon(
                                    active ? Icons.check : Icons.text_fields,
                                    size: 15,
                                    color: active ? p.accent : p.dim,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    e,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.text,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.translate,
                                  size: 14,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  encoding,
                                  style: TextStyle(fontSize: 12, color: p.text),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: p.dim,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SmoothSingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        text,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openVideoChooser(MediaNode n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: Text(context.l10n.workPageOpenVideoChooserText),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchExternal(n);
            },
            child: Text(context.l10n.workPageOpenVideoChooserText3),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _playAsAudio(n);
            },
            child: Text(context.l10n.workPageOpenVideoChooserText2),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternal(MediaNode n) async {
    final l10n = context.l10n;
    final url = n.url;
    if (url == null) {
      _toast(l10n.playerPageOpenCurrentToast);
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _toast(l10n.settingsPageOpenRepoToast);
  }

  List<PlaylistTrack> _selectedAudioTracks() {
    if (_tree == null) return const [];
    final index = _indexForTree();
    final selectedParents = List<bool>.filled(index.rows.length, false);
    final byPath = <String, PlaylistTrack>{};
    for (final row in index.rows) {
      final n = row.node;
      final parentSelected =
          row.parentIndex != null && selectedParents[row.parentIndex!];
      selectedParents[row.index] =
          parentSelected || (n.isDir && _selection.paths.contains(n.path));
      if (_isAudio(n) &&
          (parentSelected ||
              (_selection.paths.contains(n.path) &&
                  n.url != null &&
                  n.url!.isNotEmpty))) {
        byPath[n.path] = PlaylistTrack(
          title: n.title,
          path: n.path,
          url: n.url,
          duration: n.duration,
        );
      }
    }
    return byPath.values.toList();
  }

  void _addToPlaylist() {
    if (_selection.paths.isEmpty) {
      _toast(context.l10n.workPageAddToPlaylistToast);
      return;
    }
    final tracks = _selectedAudioTracks();
    if (tracks.isEmpty) {
      _toast(context.l10n.workPageAddToPlaylistToast3);
      return;
    }
    final existing = app.playlists.keys.toList();
    var newMode = existing.isEmpty;
    var chosen = existing.isEmpty ? '' : existing.first;
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.workPageAddToPlaylistText2,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.workPageAddToPlaylistText4(
                      (tracks.length).toString(),
                    ),
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                  const SizedBox(height: 10),
                  ...existing.map(
                    (pl) => InkWell(
                      onTap: () => setSheet(() {
                        newMode = false;
                        chosen = pl;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              !newMode && chosen == pl
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: !newMode && chosen == pl
                                  ? p.accent
                                  : p.dim,
                            ),
                            const SizedBox(width: 10),
                            Text(pl, style: const TextStyle(fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setSheet(() => newMode = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            newMode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: newMode ? p.accent : p.dim,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.l10n.playlistsPageBuildText2,
                            style: TextStyle(fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (newMode)
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 13, color: p.text),
                      decoration: InputDecoration(
                        hintText: context.l10n.playlistsPageNameHintText,
                        hintStyle: TextStyle(fontSize: 13, color: p.dim),
                        filled: true,
                        fillColor: p.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide(color: p.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide(color: p.accent),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      final name = newMode ? nameCtrl.text.trim() : chosen;
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.workPageAddToPlaylistText3,
                            ),
                          ),
                        );
                        return;
                      }
                      app.addWorkToPlaylist(name, work, tracks);
                      Navigator.pop(ctx);
                      _selection.clear();
                      setState(() {});
                      _toast(
                        context.l10n.workPageAddToPlaylistToast2(
                          (name).toString(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.workPageAddToPlaylistText,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _mediaIcon(MediaNode n, bool open) {
    if (n.isDir) return open ? Icons.folder_open : Icons.folder;
    if (_isAudio(n)) return Icons.music_note;
    if (_isVideo(n)) return Icons.movie_outlined;
    if (_isText(n)) return Icons.description_outlined;
    if (_isImage(n)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  bool _hasDownloadedContent(MediaNode node) {
    final item = downloadItem;
    if (item == null) return true;
    final index = _visibleIndex ?? _indexForTree();
    final row = index.byPath[node.path];
    if (row == null) return false;
    final manager = DownloadManager.instance;
    for (var i = row.fileStart; i < row.fileEnd; i++) {
      if (manager.isDownloaded(item, index.files[i])) return true;
    }
    return false;
  }

  /// 指针落在哪一行上（只遍历已构建的可见行）。
  int? _rowIndexAt(Offset globalPosition) {
    for (var i = 0; i < _visibleRows.length; i++) {
      final context = _rowKeys[_visibleRows[i].node.path]?.currentContext;
      final box = context?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  void _beginDragSelect(MediaNode node) {
    final anchor = _visibleRows.indexWhere((row) => row.node.path == node.path);
    if (anchor < 0) return;
    _dragBasePaths = Set<String>.of(_selection.paths);
    _dragAnchorRow = anchor;
    _dragLastRow = null;
    _dragSelectValue = _selection.state(node) != true;
    HapticFeedback.selectionClick();
    _applyDragRange(anchor);
  }

  /// 从快照重算 [锚点..当前行] 区间；划出区间的行随快照一起复原。
  void _applyDragRange(int rowIndex) {
    final base = _dragBasePaths;
    final anchor = _dragAnchorRow;
    if (base == null || anchor == null || _dragLastRow == rowIndex) return;
    _dragLastRow = rowIndex;
    final roots = _tree ?? const <MediaNode>[];
    _selection.restorePaths(base);
    for (
      var i = math.min(anchor, rowIndex);
      i <= math.max(anchor, rowIndex);
      i++
    ) {
      _selection.setSelected(_visibleRows[i].node, _dragSelectValue, roots);
    }
    setState(() {});
  }

  void _endDragSelect() {
    _stopAutoScrollTimer();
    _lastDragPosition = null;
    _dragBasePaths = null;
    _dragAnchorRow = null;
    _dragLastRow = null;
    _mouseDragPending = false;
    _mouseDownNode = null;
  }

  void _selectFiles({required bool invert}) {
    final roots = _tree;
    if (roots == null) return;
    final scope = _indexForVisibleTree();
    _endDragSelect();
    setState(() {
      if (invert) {
        _selection.invert(roots, scope: scope);
      } else {
        _selection.selectAll(roots, scope: scope);
      }
    });
  }

  /// 鼠标在 Windows 上同一次拖动不会走长按，所以按下后越过 slop 即起手；
  /// 触摸屏仍走长按，避免和页面滚动争手势。
  void _onSelectPointerDown(PointerDownEvent event, MediaNode node) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (_dragBasePaths != null) return;
    _mouseDownNode = node;
    _mouseDownPosition = event.position;
    _mouseDragPending = true;
  }

  void _onSelectPointerMove(PointerMoveEvent event) {
    if (!_mouseDragPending) return;
    final node = _mouseDownNode;
    if (node == null) return;
    if (_dragBasePaths == null) {
      if ((event.position - _mouseDownPosition).distance < kTouchSlop) return;
      _beginDragSelect(node);
    }
    _onDragMove(event.position);
  }

  void _onSelectPointerUp(PointerUpEvent event) {
    if (!_mouseDragPending) return;
    _endDragSelect();
  }

  /// 拖动中指针位置更新：命中某行就延展区间，靠近视口上下边缘时继续滚动。
  void _onDragMove(Offset globalPosition) {
    _lastDragPosition = globalPosition;
    _autoScrollForDrag(globalPosition);
    final rowIndex = _rowIndexAt(globalPosition);
    if (rowIndex != null) _applyDragRange(rowIndex);
    _ensureAutoScrollTimer();
  }

  /// 指针停在边缘不动时不会再收到 move 事件，用定时器继续滚动并延展区间。
  void _ensureAutoScrollTimer() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final position = _lastDragPosition;
      if (position == null || _dragBasePaths == null) {
        _stopAutoScrollTimer();
        return;
      }
      if (!_autoScrollForDrag(position)) {
        _stopAutoScrollTimer();
        return;
      }
      final rowIndex = _rowIndexAt(position);
      if (rowIndex != null) _applyDragRange(rowIndex);
    });
  }

  void _stopAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// 拖到视口上下边缘时继续滚动，否则手指出屏后就只能选到已构建的行。
  /// 返回是否真的滚动了。
  bool _autoScrollForDrag(Offset globalPosition) {
    if (!_pageScroll.hasClients) return false;
    final screen = MediaQuery.sizeOf(context);
    const edge = 72.0;
    const step = 14.0;
    final position = _pageScroll.position;
    double delta = 0;
    if (globalPosition.dy > screen.height - edge) {
      delta = step;
    } else if (globalPosition.dy < edge + kToolbarHeight) {
      delta = -step;
    }
    if (delta == 0) return false;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return false;
    _pageScroll.jumpTo(next);
    return true;
  }

  Widget _nodeRow(
    MediaNode n,
    int depth,
    List<MediaNode> siblings, {
    required bool isLast,
  }) {
    final checked = _selection.state(n);
    final open = _expanded.contains(n.path);
    final hasVisibleChildren = n.isDir && open && n.children.isNotEmpty;
    final translatedName = app.translatedTrack(work.rj, n.path);
    final downloaded = downloadItem == null
        ? true
        : DownloadManager.instance.isDownloaded(downloadItem!, n);
    final hasDownloadedContent = n.isDir
        ? _hasDownloadedContent(n)
        : downloaded;
    final fileStyle = TextStyle(
      fontSize: 12.5,
      color: hasDownloadedContent ? p.text : p.dim,
      decoration: hasDownloadedContent
          ? TextDecoration.none
          : TextDecoration.lineThrough,
      decorationColor: p.dim,
    );
    return InkWell(
      onLongPress: () async {
        final l10n = context.l10n;
        await Clipboard.setData(ClipboardData(text: n.title));
        if (mounted) _toast(l10n.workPageNodeRowToast((n.title).toString()));
      },
      onTap: () {
        if (n.isDir) {
          setState(() {
            open ? _expanded.remove(n.path) : _expanded.add(n.path);
            _rowsDirty = true;
          });
        } else {
          if (_isAudio(n)) {
            _playFiles(siblings, selected: n);
          } else {
            _openFile(n, siblings);
          }
        }
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 6 + (depth * 16).clamp(0, 96).toDouble(),
          right: 4,
          top: 9,
          bottom: 9,
        ),
        decoration: hasVisibleChildren || !isLast
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: p.line)),
              )
            : null,
        child: Row(
          children: [
            Icon(
              _mediaIcon(n, open),
              size: 17,
              color: n.isDir ? p.accent : p.dim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fileStyle,
                  ),
                  if (translatedName != null && translatedName != n.title)
                    Text(
                      translatedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: p.accent,
                        decoration: hasDownloadedContent
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                        decorationColor: p.dim,
                      ),
                    ),
                ],
              ),
            ),
            // 复选框一侧兼作滑动选中区：触摸屏长按起手，鼠标按住越过 slop
            // 即起手（Windows 上鼠标拖拽不会触发长按）；划过的区间成片切换，
            // 缩回则复原。
            Listener(
              onPointerDown: (event) => _onSelectPointerDown(event, n),
              onPointerMove: _onSelectPointerMove,
              onPointerUp: _onSelectPointerUp,
              onPointerCancel: (_) => _onSelectPointerUp,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => _beginDragSelect(n),
                onLongPressMoveUpdate: (details) =>
                    _onDragMove(details.globalPosition),
                onLongPressEnd: (_) => _endDragSelect(),
                onLongPressCancel: _endDragSelect,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Checkbox(
                    tristate: n.isDir,
                    value: checked,
                    activeColor: p.accent,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) =>
                        setState(() => _selection.toggle(n, _tree ?? const [])),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fav = app.isFavorited(work);
    final zhTitle = app.translatedTitle(work.rj);
    final miniVisible = app.playing || app.hasQueue;
    // 竖屏时把多语言入口移到下一行，避免作品编号、分级和日期挤压它。
    final splitWorkMetadata =
        !app.isDlsite &&
        MediaQuery.orientationOf(context) == Orientation.portrait &&
        _languageEditions.isNotEmpty;
    final visibleTree = _tree == null ? null : _indexForVisibleTree().roots;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.workDetails),
        leading: const BackButton(),
        actions: [
          if (_selection.paths.isNotEmpty) ...[
            IconButton(
              tooltip: context.l10n.selectAll,
              onPressed: () => _selectFiles(invert: false),
              icon: const Icon(Icons.select_all),
            ),
            IconButton(
              tooltip: context.l10n.invertSelection,
              onPressed: () => _selectFiles(invert: true),
              icon: const Icon(Icons.flip_to_back),
            ),
          ] else
            _markButton(),
          PopupMenuButton<String>(
            tooltip: context.l10n.more,
            icon: const Icon(Icons.more_vert),
            onSelected: _onMoreAction,
            itemBuilder: (_) => [
              if (downloadItem != null)
                PopupMenuItem(
                  value: 'deleteLocal',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: _onDeleteWorkLongPress,
                    child: _WorkMenuEntry(
                      icon: Icons.delete_outline,
                      label: context.l10n.delete,
                      destructive: true,
                    ),
                  ),
                ),
              PopupMenuItem(
                value: 'refresh',
                child: _WorkMenuEntry(
                  icon: Icons.refresh,
                  label: context.l10n.refresh,
                ),
              ),
              PopupMenuItem(
                value: 'dictationTranslation',
                child: _WorkMenuEntry(
                  icon: Icons.graphic_eq,
                  label: context.l10n.dictationTranslationPageBuildText,
                ),
              ),
              PopupMenuItem(
                value: 'addToPlaylist',
                child: _WorkMenuEntry(
                  icon: Icons.playlist_add,
                  label: context.l10n.workPageBuildLabel2,
                ),
              ),
              if (!app.isDlsite)
                PopupMenuItem(
                  value: 'review',
                  child: _WorkMenuEntry(
                    icon: Icons.chat_bubble_outline,
                    label: context.l10n.workPageBuildLabel,
                  ),
                ),
              if (!app.isDlsite)
                PopupMenuItem(
                  value: 'asmr',
                  child: _WorkMenuEntry(
                    icon: Icons.open_in_new,
                    label: context.l10n.workPageBuildLabel5,
                  ),
                ),
              PopupMenuItem(
                value: 'dlsite',
                child: _WorkMenuEntry(
                  icon: Icons.open_in_new,
                  label: context.l10n.workPageBuildLabel4,
                ),
              ),
              if (!app.isDlsite)
                PopupMenuItem(
                  value: 'mediaOnly',
                  child: MenuItem(
                    label: context.l10n.workPageBuildLabel3,
                    selected: app.mediaFilesOnly,
                    checkbox: true,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SmoothCustomScrollView(
            controller: _pageScroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _showCover,
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: CoverArt(
                              work: work,
                              radius: 18,
                              showBadges: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                work.title,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                              if (zhTitle != null && zhTitle != work.title)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    zhTitle,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: p.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              if (!app.isDlsite) _ratingStars(),
                              const SizedBox(height: 7),
                              if (splitWorkMetadata)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _rjChip(),
                                        if (work.ageKnown)
                                          AgeBadge(age: work.age),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (work.releaseDate.isNotEmpty)
                                          _releaseDateChip(work.releaseDate),
                                        if (!app.isDlsite)
                                          _languageEditionsButton(),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _rjChip(),
                                    if (work.ageKnown) AgeBadge(age: work.age),
                                    if (work.releaseDate.isNotEmpty)
                                      _releaseDateChip(work.releaseDate),
                                    if (!app.isDlsite &&
                                        _languageEditions.isNotEmpty)
                                      _languageEditionsButton(),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) => Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _linkChip(
                                      Icons.storefront_outlined,
                                      work.circle,
                                      () => _searchAndBack(work.circle),
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    if (work.va
                                        .replaceFirst('CV. ', '')
                                        .isNotEmpty)
                                      _linkChip(
                                        Icons.person_outline,
                                        work.va.replaceFirst('CV. ', ''),
                                        _selectVoiceActor,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.l10n.workPageBuildText9(
                                  (work.dur).toString(),
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final l10n = context.l10n;
                              try {
                                await ApiService.toggleFavorite(app, work);
                                if (mounted) {
                                  setState(() {});
                                }
                              } catch (e) {
                                if (mounted) {
                                  _toast(
                                    l10n.workPageBuildToast((e).toString()),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              fav ? Icons.favorite : Icons.favorite_border,
                              size: 17,
                            ),
                            label: Text(
                              fav
                                  ? context.l10n.workPageBuildText
                                  : context.l10n.favorites,
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.text,
                              side: BorderSide(color: p.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: GestureDetector(
                            onLongPress: _pickEngine,
                            child: OutlinedButton.icon(
                              onPressed: _translating ? null : _translateTitles,
                              icon: _translating
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.translate, size: 17),
                              label: Text(
                                _translating
                                    ? context.l10n.workPageBuildText2
                                    : app.translated.containsKey(work.rj)
                                    ? context.l10n.workPageBuildText5
                                    : context.l10n.translate,
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: p.text,
                                side: BorderSide(color: p.line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addToPlaylist,
                            icon: const Icon(Icons.playlist_add, size: 17),
                            label: Text(
                              context.l10n.workPageBuildText6,
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.text,
                              side: BorderSide(color: p.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _downloadSelected,
                            icon: const Icon(Icons.download_outlined, size: 17),
                            label: Text(
                              context.l10n.workPageBuildText7,
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.text,
                              side: BorderSide(color: p.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ...work.tags.map(
                          (t) => _tagChip(
                            work.tagLabel(t, Localizations.localeOf(context)),
                            gray: work.grayTags.contains(t),
                            onTap: () => _searchAndBack(t),
                            onLongPress: () => _blacklistTag(t),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _tree == null
                          ? context.l10n.workPageBuildText3
                          : context.l10n.workPageBuildText8,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: visibleTree != null && visibleTree.isNotEmpty
                    ? MediaTreeSliver(
                        rows: _visibleRows,
                        header: _smartTarget == null
                            ? null
                            : Material(
                                type: MaterialType.transparency,
                                child: _allFilesRow(),
                              ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.line),
                        ),
                        // 每行自带一层透明 Material：悬停高亮画在本行内，
                        // 不会漏到卡片圆角的缺口上（页面级 Material 在卡片裁剪之外）
                        rowBuilder: (context, row) => Material(
                          type: MaterialType.transparency,
                          key: _rowKeys.putIfAbsent(
                            row.node.path,
                            GlobalKey.new,
                          ),
                          child: _nodeRow(
                            row.node,
                            row.depth,
                            row.siblings,
                            isLast: identical(row, _visibleRows.last),
                          ),
                        ),
                      )
                    : SliverToBoxAdapter(child: _treePlaceholder()),
              ),
              if (!app.isDlsite && _similarWorks.isNotEmpty)
                ..._similarWorksSlivers(),
              SliverToBoxAdapter(
                child: SizedBox(height: miniVisible ? 100 : 40),
              ),
            ],
          ), // 迷你播放器浮窗（与首页一致），底部预留空白避免遮挡内容
          if (miniVisible)
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: MiniPlayer(app: app),
            ),
        ],
      ),
    );
  }

  /// 相似作品：与首页作品流一致的竖向卡片网格，放在文件列表下方。
  /// 接近底部时接入下一批，后台维持两批预取。
  List<Widget> _similarWorksSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.workPageSimilarWorksSliversText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.muted,
                  ),
                ),
              ),
              if (_similarTotal > 0)
                Text(
                  '${_similarWorks.length}/$_similarTotal',
                  style: TextStyle(fontSize: 11.5, color: p.dim),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        // 每行卡片高度由内容决定（标题行数、标签多少不同），行高跟随该行
        // 最高的卡片，不能用固定 aspectRatio 的 SliverGrid。
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            const gap = 13.0;
            final cols = (constraints.crossAxisExtent / 210)
                .floor()
                .clamp(2, 8)
                .toInt();
            final tile =
                (constraints.crossAxisExtent - gap * (cols - 1)) / cols;
            final rows = (_similarWorks.length + cols - 1) ~/ cols;
            return SliverList.builder(
              itemCount: rows,
              itemBuilder: (context, r) {
                final start = r * cols;
                final end = math.min(start + cols, _similarWorks.length);
                return Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = start; i < end; i++) ...[
                        if (i > start) const SizedBox(width: gap),
                        SizedBox(
                          width: tile,
                          child: WorkCard(
                            work: _similarWorks[i],
                            index: i,
                            cardBackground: true,
                            onTap: () => Navigator.of(
                              context,
                            ).push(buildWorkRoute(app, _similarWorks[i])),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Center(
            child: _similarLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: p.accent,
                    ),
                  )
                : _similarHasMore
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _loadSimilarWorks(reset: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        _similarAppendError
                            ? context.l10n.retry
                            : context.l10n.workPageSimilarWorksSliversText2,
                        style: TextStyle(fontSize: 12, color: p.accent),
                      ),
                    ),
                  )
                : Text(
                    context.l10n.workPageSimilarWorksSliversText3,
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
          ),
        ),
      ),
    ];
  }

  /// 页面滚到接近底部时自动加载下一批相似作品。
  void _onPageScroll() {
    if (!_pageScroll.hasClients) return;
    if (!_similarHasMore ||
        _similarAppending ||
        _similarAppendError ||
        _similarWorks.isEmpty) {
      return;
    }
    final position = _pageScroll.position;
    if (position.hasContentDimensions && position.extentAfter <= 400) {
      _loadSimilarWorks(reset: false);
    }
  }

  Widget _allFilesRow() => InkWell(
    onTap: _showAllFiles,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_upward, size: 16, color: p.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.workPageAllFilesRowText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.accent,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: p.dim),
        ],
      ),
    ),
  );

  Widget _treePlaceholder() {
    if (_tree == null && !_tracksFailed) {
      return Pulse(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: List.generate(
              6,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SkeletonBox(width: 20, height: 20, radius: 6),
                    const SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 12, radius: 6)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Center(
        child: Text(
          _tracksFailed
              ? context.l10n.workPageTreePlaceholderText3
              : app.mediaFilesOnly
              ? context.l10n.workPageTreePlaceholderText2
              : context.l10n.workPageTreePlaceholderText,
          style: TextStyle(fontSize: 12.5, color: p.dim),
        ),
      ),
    );
  }

  void _showCover() {
    final url = work.coverUrl;
    if (url == null || url.isEmpty) {
      _toast(context.l10n.playerPageOpenCurrentToast);
      return;
    }
    _openPreview([url], 0);
  }

  /// 跳回首页并搜索
  void _searchAndBack(String q) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.requestSearch(q);
  }

  Future<void> _selectVoiceActor() async {
    final l10n = context.l10n;
    final names = work.va
        .replaceFirst('CV. ', '')
        .split(' / ')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (names.isEmpty) return;
    if (names.length == 1) {
      _searchAndBack(names.single);
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.workPageSelectedText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SmoothSingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in names)
                            _linkChip(
                              Icons.person_outline,
                              name,
                              () => Navigator.of(dialogContext).pop(name),
                              maxWidth: constraints.maxWidth,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) _searchAndBack(selected);
  }

  Widget _linkChip(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required double maxWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: p.accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _releaseDateChip(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: p.line),
      ),
      child: Text(date, style: TextStyle(fontSize: 11.5, color: p.muted)),
    );
  }

  Widget _rjChip() {
    return InkWell(
      onTap: _copyRj,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(work.rj, style: TextStyle(fontSize: 11.5, color: p.muted)),
      ),
    );
  }

  Widget _languageEditionsButton() {
    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: _openingLanguageEdition ? null : _showLanguageEditions,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: p.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          context.l10n.workPageLanguageEditionsButtonText,
          style: TextStyle(
            fontSize: 11.5,
            decoration: TextDecoration.underline,
            decorationColor: p.accent,
          ),
        ),
      ),
    );
  }

  /// 作品标签 chip：灰色标签为低愿力样式；点击搜索、长按加入黑名单
  Widget _tagChip(
    String t, {
    required bool gray,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: gray ? p.surface2 : p.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: gray ? p.dim : p.line),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12,
            color: gray ? p.dim : p.text,
            fontStyle: gray ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  /// 长按翻译键：快速切换翻译引擎
  Future<void> _pickEngine() async {
    final l10n = context.l10n;
    final engines = [
      ('google', l10n.workPageEnginesEngines3),
      ('microsoft', l10n.workPageEnginesEngines4),
      ('deepl', l10n.workPageEnginesEngines),
      ('index', l10n.workPageEnginesEngines5),
      ('openai', l10n.workPageEnginesEngines2),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 14),
              Text(
                l10n.workPageSelectedText2,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...engines.map((e) {
                final on = app.engine == e.$1;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(ctx, e.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: on
                          ? p.accent.withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          on
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 19,
                          color: on ? p.accent : p.dim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.$2,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: on ? p.accent : p.text,
                              fontWeight: on
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != app.engine) {
      app.setEngine(selected);
    }
  }

  /// 长按标签：确认加入黑名单
  Future<void> _blacklistTag(String t) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(l10n.workPageOkText),
        content: Text(
          l10n.workPageOkText2(
            work.tagLabel(t, Localizations.localeOf(context)),
          ),
          style: TextStyle(fontSize: 13.5, color: p.text, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm, style: TextStyle(color: p.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      app.toggleBlacklist('tag', t);
    }
  }

  Future<void> _translateTitles() async {
    final l10n = context.l10n;
    // 已翻译：再次点击取消翻译（恢复原文）
    if (app.translated.containsKey(work.rj)) {
      app.removeTranslated(work.rj);
      if (mounted) setState(() {});
      _toast(l10n.workPageTranslateTitlesToast);
      return;
    }
    if (app.engine == 'openai' || app.engine == 'index') {
      final cfg = app.activeAiConfig;
      if ((cfg['base'] ?? '').trim().isEmpty ||
          (cfg['model'] ?? '').trim().isEmpty) {
        _toast(l10n.workPageTranslateTitlesToast4);
        return;
      }
    } else if (app.engine == 'deepl') {
      if (app.deeplKey.trim().isEmpty) {
        _toast(l10n.workPageTranslateTitlesToast6);
        return;
      }
    } else if (app.engine != 'google' && app.engine != 'microsoft') {
      _toast(l10n.workPageTranslateTitlesToast2);
      return;
    }
    if (_tree == null) {
      _toast(
        _tracksFailed
            ? l10n.workPageTreePlaceholderText3
            : l10n.workPageOnMoreActionToast,
      );
      return;
    }
    final audio = _collectAudio(_tree!);
    final lines = [work.title, ...audio.map((n) => n.title)];
    _toast(l10n.workPageTranslateTitlesToast5((lines.length).toString()));
    setState(() => _translating = true);
    try {
      final joined = lines.join('\n');
      final target = app.resolvedTranslationTarget;
      final source = app.translationSource;
      final zh = switch (app.engine) {
        'google' => await apiTranslateGoogle(
          text: joined,
          src: source,
          dst: target,
        ),
        'microsoft' => await apiTranslateMicrosoft(
          text: joined,
          src: source,
          dst: target,
        ),
        'deepl' => await apiTranslateDeepl(
          text: joined,
          src: source,
          dst: target,
          apiKey: app.deeplKey,
        ),
        _ => await apiTranslateOpenai(
          baseUrl: app.activeAiConfig['base']!,
          model: app.activeAiConfig['model']!,
          apiKey: app.activeAiConfig['key'] ?? '',
          text:
              '[[KIKOETA_TARGET:$target]]\n[[KIKOETA_SOURCE:$source]]\n$joined',
          temperature: 0.2,
        ),
      };
      // 保留空行位置，避免兼容模型漏译某一行后把后续曲目错位映射。
      final parts = zh.replaceAll('\r\n', '\n').split('\n');
      if (parts.every((part) => part.trim().isEmpty)) {
        throw FormatException(l10n.workPageTranslateTitlesFormatException);
      }
      final trackZh = <String, String>{};
      for (var i = 0; i < audio.length; i++) {
        final translation = i + 1 < parts.length ? parts[i + 1].trim() : '';
        if (translation.isNotEmpty) {
          trackZh[audio[i].path] = translation;
        }
      }
      app.saveTranslated(
        work.rj,
        parts.first.trim().isNotEmpty ? parts.first.trim() : work.title,
        trackZh,
      );
      if (mounted) {
        setState(() {});
        _toast(l10n.workPageTranslateTitlesToast7((trackZh.length).toString()));
      }
    } catch (e) {
      if (mounted) {
        _toast(
          l10n.workPageTranslateTitlesToast3(e.toString()),
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  void _toast(
    String msg, {
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), duration: duration));
  }
}

/// 智能路径统计项：某目录下音频总时长 / 各扩展名文件数 / 是否含效果音
class _DirStat {
  final List<String> path;
  int duration;
  final Map<String, int> byExt;
  final bool se;

  _DirStat({
    required this.path,
    required this.duration,
    required this.byExt,
    required this.se,
  });
}

/// 预览图的缩放/平移状态。放进 ValueNotifier：手势期间只通知 Transform 重建，
/// 不触发整页 setState（Flutter 官方 InteractiveViewer 内部就是这套做法）。
class _ViewState {
  const _ViewState(this.scale, this.offset);
  const _ViewState.initial() : scale = 1, offset = Offset.zero;

  final double scale;
  final Offset offset;
}

/// 评价与标记对话框的返回值：保存后的进度/评论，或已删除。
class _ReviewResult {
  final String? progress;
  final String reviewText;
  final bool deleted;

  const _ReviewResult.saved({required this.progress, required this.reviewText})
    : deleted = false;

  const _ReviewResult.deleted()
    : progress = null,
      reviewText = '',
      deleted = true;
}

/// 评价与标记：顶部居中播放状态，下方评论输入框，左下删除、右下确定。
class _ReviewDialog extends StatefulWidget {
  final AppState app;
  final Work work;
  final double? userRating;
  final String? progress;
  final String? reviewText;

  const _ReviewDialog({
    required this.app,
    required this.work,
    this.userRating,
    this.progress,
    this.reviewText,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController _text;
  String? _progress;
  bool _saving = false;

  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.reviewText ?? '');
    _progress = widget.progress;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ApiService.submitReview(
        widget.app,
        widget.work,
        rating: widget.userRating,
        reviewText: _text.text.trim(),
        progress: _progress,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _ReviewResult.saved(progress: _progress, reviewText: _text.text.trim()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _notify(l10n.workPageSubmitNotify((e).toString()));
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.workPageConfirmedText),
        content: Text(l10n.workPageConfirmedText3),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ApiService.deleteReview(widget.app, widget.work);
      if (!mounted) return;
      Navigator.of(context).pop(const _ReviewResult.deleted());
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _notify(l10n.workPageDeleteNotify((e).toString()));
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        context.l10n.workPageBuildText4,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in workProgressLabels.entries)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _progress = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _progress == entry.key
                                ? p.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _progress == entry.key
                                  ? Colors.white
                                  : p.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 6,
              style: TextStyle(fontSize: 13, color: p.text),
              decoration: InputDecoration(
                hintText: context.l10n.workPageBuildHintText,
                hintStyle: TextStyle(fontSize: 13, color: p.dim),
                filled: true,
                fillColor: p.surface2,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: p.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: p.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: p.accent),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: _saving ? null : _delete,
          child: Text(
            context.l10n.workPageConfirmedText,
            style: TextStyle(color: p.red),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : _submit,
          child: Text(
            context.l10n.confirm,
            style: TextStyle(color: p.accent, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// 全屏图片预览：左右滑动或屏幕两侧按钮切换同一路径下的图片，
/// 桌面滚轮缩放、移动端双指缩放；两侧按钮与页码在无操作 1s 后渐隐，
/// 缩放不会唤回已隐藏的 UI，只有单击才会恢复。
class _ImagePreviewDialog extends StatefulWidget {
  const _ImagePreviewDialog({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog>
    with SingleTickerProviderStateMixin {
  static const double _maxScale = 6;
  static const Duration _idleHideDelay = Duration(seconds: 1);
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  static const Duration _turnDuration = Duration(milliseconds: 220);
  static const double _turnRatio = 0.2;

  late int _index = widget.initialIndex.clamp(
    0,
    math.max(0, widget.urls.length - 1),
  );

  /// 图片宽高比：把缩放/平移限制在图片实际显示范围内，避免拖出大片空白
  final Map<String, double> _ratios = {};
  final Set<String> _ratioPending = {};

  /// 缩放/平移与拖拽位移走 ValueNotifier：手势每帧只重建 Transform 本身，
  /// 图片、按钮、页码都不参与重建
  final ValueNotifier<_ViewState> _view = ValueNotifier(
    const _ViewState.initial(),
  );
  final ValueNotifier<double> _drag = ValueNotifier(0);

  double get _scale => _view.value.scale;
  Offset get _offset => _view.value.offset;

  int _turnDir = 0; // 正在动画切换的方向（-1/0/1）
  bool _pinched = false; // 本次手势是否已进入双指缩放

  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _startDrag = 0;

  Size _viewport = Size.zero;

  bool _chrome = true;
  Timer? _idleTimer;

  int _pointers = 0;
  bool _multiPointer = false;

  late final AnimationController _turnAnim = AnimationController(
    vsync: this,
    duration: _turnDuration,
  );
  late final CurvedAnimation _turnCurve = CurvedAnimation(
    parent: _turnAnim,
    curve: Curves.easeOutCubic,
  );
  Tween<double> _dragTween = Tween<double>(begin: 0, end: 0);

  String get _current => widget.urls[_index];

  @override
  void initState() {
    super.initState();
    _turnAnim.addListener(_onTurnTick);
    _turnAnim.addStatusListener(_onTurnStatus);
    _idleTimer = Timer(_idleHideDelay, _hideChrome);
    // 预取放在首帧之后，此时 MediaQuery 与图片缓存都已就绪
    WidgetsBinding.instance.addPostFrameCallback((_) => _warm());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _view.dispose();
    _drag.dispose();
    _turnCurve.dispose();
    _turnAnim.dispose();
    super.dispose();
  }

  // ── 图片加载 ───────────────────────────────────────────────

  ImageProvider _provider(String url) {
    final mq = MediaQuery.of(context);
    // 可缩放查看需要比封面更高的解码分辨率，上限 2048px：
    // 同时预取相邻图片，避免三张全屏图占满图片缓存
    final width = (mq.size.width * mq.devicePixelRatio).round().clamp(
      160,
      2048,
    );
    return ResizeImage.resizeIfNeeded(width, null, RustImageProvider(url));
  }

  /// 记录宽高比，异步完成后刷新一次
  void _trackRatio(String url) {
    if (_ratios.containsKey(url) || !_ratioPending.add(url)) return;
    final stream = _provider(
      url,
    ).resolve(createLocalImageConfiguration(context));
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        _ratioPending.remove(url);
        if (!mounted || info.image.height <= 0) return;
        setState(() => _ratios[url] = info.image.width / info.image.height);
      },
      onError: (_, _) {
        stream.removeListener(listener);
        _ratioPending.remove(url);
      },
    );
    stream.addListener(listener);
  }

  /// 记录当前图片比例并预取相邻图片，滑动切换时不必等加载
  void _warm() {
    if (!mounted) return;
    _trackRatio(_current);
    for (final i in [_index - 1, _index + 1]) {
      if (i < 0 || i >= widget.urls.length) continue;
      _trackRatio(widget.urls[i]);
      precacheImage(_provider(widget.urls[i]), context, onError: (_, _) {});
    }
  }

  // ── 渐隐控制 ───────────────────────────────────────────────

  void _hideChrome() {
    if (mounted && _chrome) setState(() => _chrome = false);
  }

  /// 有操作时重新计时；已隐藏的 UI 不会被唤回
  void _activity() {
    if (!_chrome) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleHideDelay, _hideChrome);
  }

  /// 鼠标在窗口内移动：控件保持显示（已隐藏则唤回）并重新计时
  void _keepChrome() {
    if (!_chrome) setState(() => _chrome = true);
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleHideDelay, _hideChrome);
  }

  void _toggleChrome() {
    _idleTimer?.cancel();
    if (_chrome) {
      setState(() => _chrome = false);
      return;
    }
    setState(() => _chrome = true);
    _idleTimer = Timer(_idleHideDelay, _hideChrome);
  }

  void _handleTap() {
    // 双指缩放的收尾不算单击，不唤回 UI
    if (_multiPointer) return;
    _toggleChrome();
  }

  // ── 指针 ──────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent _) {
    _pointers++;
    if (_pointers == 1) _multiPointer = false;
    if (_pointers > 1) _multiPointer = true;
  }

  void _onPointerEnd(PointerEvent _) {
    if (_pointers > 0) _pointers--;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    // 滚轮只用于缩放：注册到信号解析器，避免被祖先滚动容器抢走
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      _zoomAt(math.exp(-scroll.scrollDelta.dy / 260), scroll.localPosition);
    });
  }

  // ── 缩放 / 平移 / 翻页 ─────────────────────────────────────

  Offset get _center => Offset(_viewport.width / 2, _viewport.height / 2);

  static double _clampD(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  /// BoxFit.contain 下图片在视口内的实际显示尺寸
  Size _fitted(Size viewport, double? ratio) {
    if (ratio == null || ratio <= 0 || viewport.isEmpty) return viewport;
    final height = viewport.width / ratio;
    return height <= viewport.height
        ? Size(viewport.width, height)
        : Size(viewport.height * ratio, viewport.height);
  }

  Offset _clampOffset(Offset value, double scale) {
    if (_viewport.isEmpty) return value;
    final content = _fitted(_viewport, _ratios[_current]);
    final maxX = math.max(0.0, (content.width * scale - _viewport.width) / 2);
    final maxY = math.max(0.0, (content.height * scale - _viewport.height) / 2);
    return Offset(
      _clampD(value.dx, -maxX, maxX),
      _clampD(value.dy, -maxY, maxY),
    );
  }

  void _zoomAt(double factor, Offset focal) {
    final current = _view.value;
    final next = _clampD(current.scale * factor, 1, _maxScale);
    if ((next - current.scale).abs() < 0.001) return;
    final u = focal - _center;
    final moved = u - (u - current.offset) * (next / current.scale);
    _view.value = _ViewState(next, _clampOffset(moved, next));
    _activity();
  }

  void _resetZoom() {
    _view.value = const _ViewState.initial();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _turnAnim.stop();
    _turnDir = 0;
    _pinched = false;
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint;
    _startDrag = _drag.value;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) {
      _pinched = true;
      final next = _clampD(_startScale * details.scale, 1, _maxScale);
      final u = details.localFocalPoint - _center;
      final moved = u - (u - _startOffset) * (next / _startScale);
      _drag.value = 0; // 双指介入时放弃未完成的翻页位移
      _view.value = _ViewState(next, _clampOffset(moved, next));
      return; // 双指缩放不唤回已隐藏的 UI
    }
    if (_scale > 1.001) {
      // 已放大：单指平移图片
      final delta = details.focalPointDelta;
      if (delta == Offset.zero) return;
      _view.value = _ViewState(_scale, _clampOffset(_offset + delta, _scale));
      return;
    }
    if (_pinched) return; // 缩放后抬起一根手指，不当作翻页拖拽
    final dx = details.localFocalPoint.dx - _startFocal.dx;
    _drag.value = _clampD(_startDrag + dx, -_viewport.width, _viewport.width);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _pinched = false;
    if (_drag.value == 0 || _scale > 1.001) return;
    _settleTurn(details.velocity.pixelsPerSecond.dx);
  }

  /// 松手后收尾：越过阈值就翻页，否则弹回
  void _settleTurn(double velocity) {
    final width = _viewport.width;
    if (width <= 0) return;
    final ratio = _drag.value / width;
    var dir = 0;
    if (ratio <= -_turnRatio || (ratio < -0.02 && velocity < -500)) {
      dir = 1;
    } else if (ratio >= _turnRatio || (ratio > 0.02 && velocity > 500)) {
      dir = -1;
    }
    if (dir != 0 && _index + dir >= 0 && _index + dir < widget.urls.length) {
      _turnDir = dir;
      _dragTween = Tween<double>(begin: _drag.value, end: -dir * width);
    } else {
      _turnDir = 0;
      _dragTween = Tween<double>(begin: _drag.value, end: 0);
    }
    _turnAnim.forward(from: 0);
  }

  void _onTurnTick() {
    if (!mounted) return;
    _drag.value = _dragTween.transform(_turnCurve.value);
  }

  void _onTurnStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final dir = _turnDir;
    _turnDir = 0;
    if (dir == 0) return;
    _drag.value = 0;
    _resetZoom();
    setState(() => _index += dir);
    _activity();
    _warm();
  }

  void _turn(int dir) {
    final next = _index + dir;
    if (next < 0 || next >= widget.urls.length) return;
    _drag.value = 0;
    _resetZoom();
    setState(() => _index = next);
    _activity();
    _warm();
  }

  // ── 构建 ──────────────────────────────────────────────────

  /// 两侧按钮与页码共用同一套渐隐
  Widget _chromeBox(Widget child) => IgnorePointer(
    ignoring: !_chrome,
    child: AnimatedOpacity(
      opacity: _chrome ? 1 : 0,
      duration: _fadeDuration,
      child: child,
    ),
  );

  Widget _sideButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.black45,
      shape: BoxShape.circle,
    ),
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 30, color: Colors.white),
    ),
  );

  /// 单张图片：按实际显示尺寸铺开。作为 ValueListenableBuilder 的 child 传入，
  /// 手势期间只更新外层 Transform，它自己不会被重建
  Widget _imageBox(String url) {
    final size = _fitted(_viewport, _ratios[url]);
    return Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Image(
          image: _provider(url),
          fit: BoxFit.contain,
          frameBuilder: (_, child, frame, _) => frame == null
              ? const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white24,
                    ),
                  ),
                )
              : child,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  /// 相邻图片常驻在视口外侧，拖拽时只更新各自的 Transform
  Widget _sideLayer(String url, double sign, double width) => Positioned.fill(
    child: ValueListenableBuilder<double>(
      valueListenable: _drag,
      builder: (context, drag, child) => Transform.translate(
        offset: Offset(drag + sign * width, 0),
        child: child,
      ),
      child: _imageBox(url),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    return MouseRegion(
      // 鼠标在窗口内移动就不隐藏控件；移出窗口或鼠标静止 1s 后隐藏
      onHover: (_) => _keepChrome(),
      onExit: (_) => _hideChrome(),
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerEnd,
                onPointerCancel: _onPointerEnd,
                onPointerSignal: _onPointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTap,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return ClipRect(
                        child: Stack(
                          children: [
                            // 相邻图片常驻视口外侧：拖拽时零 widget 构建，
                            // 只有它们的 Transform 跟着动
                            if (_index > 0)
                              _sideLayer(
                                widget.urls[_index - 1],
                                -1,
                                _viewport.width,
                              ),
                            if (_index + 1 < total)
                              _sideLayer(
                                widget.urls[_index + 1],
                                1,
                                _viewport.width,
                              ),
                            Positioned.fill(
                              child: ValueListenableBuilder<double>(
                                valueListenable: _drag,
                                builder: (context, drag, child) =>
                                    Transform.translate(
                                      offset: Offset(drag, 0),
                                      child: child,
                                    ),
                                // 缩放/平移只重建这两层 Transform，图片用 child 透传
                                child: ValueListenableBuilder<_ViewState>(
                                  valueListenable: _view,
                                  builder: (context, view, child) =>
                                      Transform.translate(
                                        offset: view.offset,
                                        child: Transform.scale(
                                          scale: view.scale,
                                          child: child,
                                        ),
                                      ),
                                  child: _imageBox(_current),
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
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: context.l10n.close,
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
            if (_index > 0)
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _chromeBox(
                    _sideButton(
                      icon: Icons.chevron_left,
                      tooltip: context.l10n.workPageBuildTooltip,
                      onPressed: () => _turn(-1),
                    ),
                  ),
                ),
              ),
            if (_index + 1 < total)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _chromeBox(
                    _sideButton(
                      icon: Icons.chevron_right,
                      tooltip: context.l10n.workPageBuildTooltip2,
                      onPressed: () => _turn(1),
                    ),
                  ),
                ),
              ),
            if (total > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: _chromeBox(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_index + 1}/$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
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
