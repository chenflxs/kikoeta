import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'services/app_paths.dart';
import 'services/player_service.dart';
import 'src/rust/api/kikoeru_api.dart';
import 'theme.dart';

final List<List<Color>> coverGrads = [
  [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
  [const Color(0xFF2563EB), const Color(0xFF06B6D4)],
  [const Color(0xFF4F46E5), const Color(0xFF8B5CF6)],
  [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
  [const Color(0xFF0EA5E9), const Color(0xFF6366F1)],
  [const Color(0xFF4338CA), const Color(0xFF0EA5E9)],
  [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
  [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
];

class CoverArt extends StatefulWidget {
  final Work work;
  final double radius;
  final Widget? child;
  final bool showBadges;
  const CoverArt({
    super.key,
    required this.work,
    this.radius = 14,
    this.child,
    this.showBadges = true,
  });

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  static const _maxRetryCount = 3;
  int _attempt = 0;
  bool _retryPending = false;

  Work get work => widget.work;
  double get radius => widget.radius;
  Widget? get child => widget.child;
  bool get showBadges => widget.showBadges;

  @override
  void didUpdateWidget(CoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.coverUrl != work.coverUrl) {
      _attempt = 0;
      _retryPending = false;
    }
  }

  void _retryAfterDelay(Object error) {
    final url = work.coverUrl;
    if (url == null) return;
    if (_attempt >= _maxRetryCount) {
      _logImageError(url, error.toString());
      return;
    }
    if (_retryPending) return;
    _retryPending = true;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryPending = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = coverGrads[work.grad % coverGrads.length];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (work.coverUrl != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (ctx, c) {
                  // 按实际显示尺寸（含设备像素比）解码封面，上限 720px：
                  // 网格小图不再全尺寸解码，显著降低内存占用与栅格上传开销
                  final cacheWidth =
                      (c.maxWidth * MediaQuery.devicePixelRatioOf(ctx))
                          .round()
                          .clamp(128, 720);
                  final image = ResizeImage.resizeIfNeeded(
                    cacheWidth,
                    null,
                    RustImageProvider(work.coverUrl!),
                  );
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('${work.coverUrl}:$_attempt'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                    builder: (ctx, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, _) {
                        unawaited(image.evict());
                        _retryAfterDelay(error);
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
              ),
            ),
          if (showBadges)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  work.rj,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
          if (showBadges)
            Positioned(top: 8, right: 8, child: AgeBadge(age: work.age)),
          ?child,
        ],
      ),
    );
  }
}

/// 无依赖的脉冲动画（骨架屏呼吸效果）
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _a = Tween(
    begin: 0.45,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _a, child: widget.child);
}

/// 骨架占位块
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.surface3,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 通过 Rust（reqwest/rustls）加载网络图片，规避 dart:io 在部分网络下的 TLS 问题
class RustImageProvider extends ImageProvider<RustImageProvider> {
  final String url;
  RustImageProvider(this.url);

  @override
  Future<RustImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<RustImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    RustImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key, decode));
  }

  Future<ImageInfo> _load(
    RustImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await apiGetBytes(url: key.url);
    // 使用传入的 decode 回调（而非直接解码），使 ResizeImage 的按尺寸解码能真正生效：
    // 封面按实际显示尺寸解码，避免全尺寸解码造成的内存与栅格压力。
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is RustImageProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

void _logImageError(String url, String error) {
  try {
    // 写入应用数据目录（Windows 为 exe 旁 data/，不污染 Temp）
    AppPaths.dataDir().then((dir) {
      final f = File('$dir${Platform.pathSeparator}kikoeta_image_error.log');
      f.writeAsStringSync('$url\n$error\n---\n', mode: FileMode.append);
    });
  } catch (_) {}
}

class AgeBadge extends StatelessWidget {
  final Age age;
  const AgeBadge({super.key, required this.age});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final (label, color) = switch (age) {
      Age.all => ('全年龄', p.green),
      Age.r15 => ('R15', p.orange),
      Age.r18 => ('R18', p.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class WorkCard extends StatelessWidget {
  final Work work;
  final int index;
  final VoidCallback onTap;
  const WorkCard({
    super.key,
    required this.work,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final tags = work.tags
        .map((t) => _TagMini(t, p, gray: work.grayTags.contains(t)))
        .toList();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArt(
              work: work,
              child: Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  work.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            work.title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  work.circle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: p.muted),
                ),
              ),
              Text(work.dur, style: TextStyle(fontSize: 10.5, color: p.dim)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: tags),
        ],
      ),
    );
  }
}

class _TagMini extends StatelessWidget {
  final String label;
  final Palette p;
  final bool gray;
  const _TagMini(this.label, this.p, {this.gray = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.surface2,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          color: gray ? p.dim : p.muted,
          fontStyle: gray ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.surface,
          border: Border.all(color: selected ? p.accent : p.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? Colors.white : p.muted,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 5), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 按可用宽度自适应列数的网格（竖屏约 2 列，横屏/宽窗自动增加）。
/// 行式懒加载：仅构建可视行，滚出视口的卡片会被回收，
/// 每张卡片包一层 RepaintBoundary 隔离重绘。
class ResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final double maxTileWidth;
  final double aspect;
  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.maxTileWidth = 210,
    this.aspect = .68,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = (c.maxWidth / maxTileWidth).floor().clamp(2, 8);
        const gap = 13.0;
        final tile = (c.maxWidth - gap * (cols - 1)) / cols;
        final rows = (itemCount + cols - 1) ~/ cols;
        return ListView.builder(
          padding: padding,
          physics: physics,
          itemCount: rows,
          itemBuilder: (ctx, r) {
            final start = r * cols;
            final end = start + cols > itemCount ? itemCount : start + cols;
            return Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start; i < end; i++) ...[
                    if (i > start) const SizedBox(width: gap),
                    SizedBox(
                      width: tile,
                      child: RepaintBoundary(child: itemBuilder(ctx, i)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 通用下拉菜单项（单选圆点 / 复选勾）
class MenuItem extends StatelessWidget {
  final String label;
  final bool selected;
  final bool checkbox;
  final VoidCallback? onTap;
  final bool enabled;
  const MenuItem({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.checkbox = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? p.accent.withValues(alpha: .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? p.accent : p.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (checkbox)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: selected ? p.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? p.accent : p.dim,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? p.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? p.accent : p.dim,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? footer;
  const MenuPanel({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Container(
      width: 176,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
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
          ...children,
          if (footer != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Divider(height: 1),
            ),
            ...footer!,
          ],
        ],
      ),
    );
  }
}

/// 首页搜索栏（输入 + 历史面板 + 筛选按钮）。
/// 由 Shell 渲染在整页遮罩之上，保证展开时仍可交互。
class HomeSearchBar extends StatefulWidget {
  final AppState app;
  const HomeSearchBar({super.key, required this.app});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

/// 迷你播放器浮窗（首页/收藏/更多/作品详情共用）
class MiniPlayer extends StatelessWidget {
  final AppState app;
  const MiniPlayer({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final w = app.playWork;
    final t = app.queue.isEmpty
        ? null
        : app.queue[app.trackIdx.clamp(0, app.queue.length - 1)];
    if (w == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/player'),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.mini,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CoverArt(work: w, radius: 10, showBadges: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    w.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                if (app.playing) {
                  // 真实暂停底层播放器（状态经 playing 事件流自动回同步）
                  try {
                    await AppPlayer.instance.player.pause();
                  } catch (_) {}
                } else {
                  // 未打开媒体（如重启恢复的队列）：进播放器页打开
                  if (!AppPlayer.instance.opened && app.queue.isNotEmpty) {
                    Navigator.of(context).pushNamed('/player');
                    return;
                  }
                  try {
                    await AppPlayer.instance.player.play();
                  } catch (_) {}
                }
              },
              icon: Icon(
                app.playing ? Icons.pause_circle : Icons.play_circle,
                size: 30,
                color: p.text,
              ),
            ),
            IconButton(
              onPressed: () {
                if (app.queue.isNotEmpty) {
                  app.trackIdx = (app.trackIdx + 1) % app.queue.length;
                }
                app.notify();
              },
              icon: const Icon(Icons.skip_next, size: 24),
              color: p.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _ctrl.text = app.peekPendingSearch() ?? '';
    // 搜索框获得焦点即自动展开
    _focus.addListener(() {
      if (_focus.hasFocus && !app.searchExpanded) {
        app.setSearchExpanded(true);
      }
    });
    app.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onAppChanged() {
    final pending = app.takePendingSearch();
    if (pending != null) {
      _ctrl.text = pending;
      _focus.unfocus();
      app.setSearchExpanded(false);
      return;
    }
    if (!app.searchExpanded && _focus.hasFocus) {
      _focus.unfocus();
    }
  }

  void _submit(String q) {
    final s = q.trim();
    app.requestSearch(s);
    _focus.unfocus();
    app.setSearchExpanded(false);
  }

  @override
  Widget build(BuildContext context) {
    final panelMax = (MediaQuery.sizeOf(context).height * 0.72).clamp(
      180.0,
      560.0,
    );
    return Row(
      children: [
        Expanded(child: _searchBar(panelMax)),
        const SizedBox(width: 8),
        _filterButton(),
      ],
    );
  }

  Widget _searchBar(double panelMax) {
    final expanded = app.searchExpanded;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: expanded ? p.accent : p.line),
          borderRadius: BorderRadius.circular(expanded ? 16 : 15),
          boxShadow: expanded
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .24),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _inputRow(),
            if (expanded)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: 1,
                child: _historyPanel(panelMax),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inputRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            const SizedBox(width: 13),
            Icon(Icons.search, size: 19, color: p.dim),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: TextStyle(fontSize: 14, color: p.text),
                decoration: InputDecoration(
                  hintText: '搜索 RJ 号、作品名、声优…',
                  hintStyle: TextStyle(fontSize: 14, color: p.dim),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _submit,
              ),
            ),
            if (_ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  app.requestSearchClear();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: p.surface3,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _historyPanel(double maxH) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '搜索历史',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.muted,
                    ),
                  ),
                ),
                if (app.history.isNotEmpty)
                  GestureDetector(
                    onTap: () => app.clearHistory(),
                    child: Text(
                      '清空',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (app.history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        size: 36,
                        color: p.dim.withValues(alpha: .6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '暂无搜索历史',
                        style: TextStyle(fontSize: 13, color: p.dim),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: app.history.asMap().entries.map((e) {
                  final i = e.key;
                  return GestureDetector(
                    onTap: () {
                      _ctrl.text = e.value;
                      _submit(e.value);
                    },
                    onLongPress: () {
                      app.history.removeAt(i);
                      app.notify();
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              '已删除「${e.value}」',
                              style: TextStyle(fontSize: 12.5, color: p.text),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(milliseconds: 1600),
                            backgroundColor: p.toast,
                          ),
                        );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border.all(color: p.line),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton() {
    final active = app.ageFilter != null || app.subOnly;
    return PopupMenuButton<int>(
      tooltip: '筛选',
      onSelected: (v) {
        if (v == 10) {
          app.subOnly = !app.subOnly;
        } else {
          // SFW 模式下不允许切到 R15/R18
          if (app.sfwMode && v != 0) return;
          app.ageFilter = app.ageFilter == v ? null : v;
        }
        app.notify();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: p.surface,
      itemBuilder: (ctx) => [
        _menuHead('年龄分级'),
        PopupMenuItem(
          value: 2,
          height: 44,
          enabled: !app.sfwMode,
          child: MenuItem(
            label: 'R18',
            selected: app.ageFilter == 2,
            enabled: !app.sfwMode,
          ),
        ),
        PopupMenuItem(
          value: 1,
          height: 44,
          enabled: !app.sfwMode,
          child: MenuItem(
            label: 'R15',
            selected: app.ageFilter == 1,
            enabled: !app.sfwMode,
          ),
        ),
        PopupMenuItem(
          value: 0,
          height: 44,
          child: MenuItem(label: '全年龄', selected: app.ageFilter == 0),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 10,
          height: 44,
          child: MenuItem(label: '仅字幕', selected: app.subOnly, checkbox: true),
        ),
      ],
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? p.accent.withValues(alpha: .1) : p.surface,
          border: Border.all(color: active ? p.accent : p.line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.filter_alt_outlined,
                size: 20,
                color: active ? p.accent : p.muted,
              ),
            ),
            if (active)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
}
