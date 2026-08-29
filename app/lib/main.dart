import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';

import 'data.dart';
import 'pages/favorites_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/more_page.dart';
import 'pages/player_page.dart';
import 'pages/settings_page.dart';
import 'pages/work_page.dart';
import 'services/player_service.dart';
import 'services/settings_store.dart';
import 'services/shortcut_service.dart';
import 'services/sleep_timer.dart';
import 'services/clipboard_watcher.dart';
import 'services/desktop_lyrics_overlay.dart';
import 'services/android_audio.dart';
import 'services/android_lyrics_overlay.dart';
import 'services/android_media3.dart';
import 'services/android_notification.dart';
import 'services/windows_tray_service.dart';
import 'services/lyrics_hub.dart';
import 'services/update_service.dart';
import 'src/rust/api/kikoeru_api.dart';
import 'theme.dart';
import 'widgets.dart';

final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.init();
  await appState.loadFromRust();
  await UpdateService.initialize();
  // Windows 首次运行：自动创建桌面/开始菜单快捷方式（仅 release，幂等）
  ShortcutService.ensureShortcuts();
  // 安卓音频控制：耳机拔出/焦点丢失 → 暂停播放
  AndroidAudio.init();
  AndroidAudio.onPauseRequested = () {
    AppPlayer.instance.player.pause();
  };
  if (!kIsWeb && Platform.isAndroid) {
    AndroidAudio.setEarPause(appState.earPause);
    AndroidAudio.setIgnoreAudioFocus(appState.ignoreAudioFocus);
  }
  if (!kIsWeb && Platform.isWindows) {
    await WindowsTrayService.instance.init(appState);
  }
  MediaKit.ensureInitialized();
  await AppPlayer.instance.setMediaCacheLimitMb(appState.mediaCacheLimitMb);
  // Jetpack Media3：锁屏/通知媒体控制（桥接到 mpv；service 在首次播放时才启动）
  // 注意：必须放在 MediaKit.ensureInitialized() 之后（AppPlayer 依赖 media_kit）
  if (!kIsWeb && Platform.isAndroid) {
    AndroidMedia3.init();
    AndroidMedia3.onCommand = _media3Command;
    _bindMedia3Sync();
  }
  // 播放器为全局单例：退出播放器页后仍把播放状态同步给应用
  AppPlayer.instance.playing.listen((p) {
    if (p != appState.playing) {
      appState.playing = p;
      appState.notify();
    }
  });
  _bindPlaybackPersistence();
  // 播放器页面可随时关闭，自动续播必须由应用常驻层处理。
  AppPlayer.instance.completed.listen((_) => _advanceAfterCompletion());
  // 定时关闭：全局计时（播放器页关闭时也生效）
  SleepTimer.start(appState);
  runApp(const KikoetaApp());
  UpdateService.startAutoCheck(appState, appNavigatorKey);
  // 剪贴板 RJ 检测（每 3 秒轮询）
  ClipboardWatcher.start(appState, appMessengerKey);
  // Android 13+ 通知权限（媒体通知/锁屏卡片；仅首次弹系统框）
  if (!kIsWeb && Platform.isAndroid) {
    AndroidNotification.requestPermission();
  }
  // 桌面歌词（Windows）
  if (!kIsWeb && Platform.isWindows) {
    await DesktopLyricsOverlay.instance.init();
    DesktopLyricsOverlay.instance.bind(
      onLockChanged: (v) => appState.setLyricsLockedDesktop(v),
      onFontSizeChanged: (v) => appState.setLyricsFontSize(v),
    );
    appState.addListener(_syncDesktopLyrics);
    _syncDesktopLyrics();
  }
  // 桌面歌词（安卓悬浮窗）
  if (!kIsWeb && Platform.isAndroid) {
    AndroidLyricsOverlay.instance.onLockChanged = (portrait, locked) {
      if (portrait) {
        appState.setLyricsLockedPortrait(locked);
      } else {
        appState.setLyricsLockedLandscape(locked);
      }
    };
    await AndroidLyricsOverlay.instance.init();
    appState.addListener(_syncAndroidLyrics);
    _syncAndroidLyrics();
  }
  LyricsHub.instance.start();
  LyricsHub.instance.bind(appState);
}

void _syncDesktopLyrics() {
  final ov = DesktopLyricsOverlay.instance;
  if (appState.desktopLyricsOn) {
    final line = LyricsHub.instance.currentLine;
    ov.show(
      text: line.isEmpty ? '暂无歌词' : line,
      fontSize: appState.lyricsFontSize,
      color: appState.lyricsColor,
      outlineColor: appState.lyricsOutlineColor,
      outlineWidth: appState.lyricsOutlineWidth,
      locked: appState.lyricsLockedDesktop,
    );
  } else {
    ov.hide();
  }
}

void _syncAndroidLyrics() {
  final ov = AndroidLyricsOverlay.instance;
  if (appState.desktopLyricsOn) {
    final portrait = _isPortraitNow();
    final locked = portrait
        ? appState.lyricsLockedPortrait
        : appState.lyricsLockedLandscape;
    ov.show(
      text: LyricsHub.instance.currentLine,
      fontSize: appState.lyricsFontSize,
      color: appState.lyricsColor,
      outlineColor: appState.lyricsOutlineColor,
      outlineWidth: appState.lyricsOutlineWidth,
      locked: locked,
      portrait: portrait,
      portraitWidthDp: _portraitWidthDp(),
    );
  } else {
    ov.hide();
  }
}

bool _isPortraitNow() {
  final size =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
  return size.height >= size.width;
}

double _portraitWidthDp() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize;
  final min = size.width < size.height ? size.width : size.height;
  return min / view.devicePixelRatio;
}

bool _autoAdvancing = false;

Future<void> _advanceAfterCompletion() async {
  final queue = appState.queue;
  if (_autoAdvancing || queue.isEmpty) return;
  _autoAdvancing = true;
  try {
    if (appState.playMode == 2) {
      await AppPlayer.instance.player.seek(Duration.zero);
      await AppPlayer.instance.player.play();
      return;
    }
    if (appState.playMode == 0 && appState.trackIdx == queue.length - 1) {
      if (appState.sleepMode == 'end' && appState.sleepPlayEndArmed) {
        SleepTimer.triggerNow(appState);
      } else {
        appState.playing = false;
        appState.resumePosition = 0;
        appState.savePlayState();
        appState.notify();
      }
      return;
    }

    appState.trackIdx = (appState.trackIdx + 1) % queue.length;
    appState.playing = true;
    appState.resumePosition = 0;
    appState.notify();
    final url = queue[appState.trackIdx].url;
    if (url == null) {
      appState.playing = false;
      appState.notify();
      return;
    }
    await AppPlayer.instance.openMediaUrl(url);
    await AppPlayer.instance.applyEqualizer(
      enabled: appState.eqOn,
      gains: appState.eqGains,
    );
    appState.savePlayState();
  } catch (_) {
    appState.playing = false;
    appState.notify();
  } finally {
    _autoAdvancing = false;
  }
}

// ---------------- Jetpack Media3 桥接（锁屏/通知媒体控制） ----------------

int _lastMedia3Pos = -1;
DateTime _lastMedia3Sync = DateTime.fromMillisecondsSinceEpoch(0);
bool _media3SessionStarted = false;
// 「不显示通知栏媒体卡片」开关的上次状态（用于切回显示时重新拉起会话服务）
bool _media3Hidden = false;
String _media3ArtworkLoadKey = '';

/// MediaSession 控制命令（Kotlin → Dart，mpv 执行）
void _media3Command(String action, int positionMs) {
  switch (action) {
    case 'play':
      AppPlayer.instance.player.play();
      break;
    case 'pause':
      AppPlayer.instance.player.pause();
      break;
    case 'stop':
      AppPlayer.instance.stop();
      break;
    case 'seekTo':
      AppPlayer.instance.player.seek(Duration(milliseconds: positionMs));
      break;
    case 'next':
      _mediaNext();
      break;
    case 'previous':
      _mediaPrev();
      break;
  }
}

Future<void> _mediaNext() async {
  final q = appState.queue;
  if (q.isEmpty) return;
  appState.trackIdx = (appState.trackIdx + 1) % q.length;
  appState.playing = true;
  appState.resumePosition = 0;
  appState.notify();
  final url = q[appState.trackIdx].url;
  if (url != null) {
    try {
      await AppPlayer.instance.openMediaUrl(url);
      AppPlayer.instance.applyEqualizer(
        enabled: appState.eqOn,
        gains: appState.eqGains,
      );
      appState.savePlayState();
    } catch (_) {}
  }
  _syncMedia3State();
}

Future<void> _mediaPrev() async {
  final q = appState.queue;
  if (q.isEmpty) return;
  appState.trackIdx = (appState.trackIdx + q.length - 1) % q.length;
  appState.playing = true;
  appState.resumePosition = 0;
  appState.notify();
  final url = q[appState.trackIdx].url;
  if (url != null) {
    try {
      await AppPlayer.instance.openMediaUrl(url);
      AppPlayer.instance.applyEqualizer(
        enabled: appState.eqOn,
        gains: appState.eqGains,
      );
      appState.savePlayState();
    } catch (_) {}
  }
  _syncMedia3State();
}

/// 上报当前播放状态到 MediaSession（通知/锁屏卡片）
void _syncMedia3State() {
  if (kIsWeb || !Platform.isAndroid) return;
  final hideCard = appState.lsCover;
  final w = appState.currentWork;
  final q = appState.queue;
  final t = q.isEmpty ? null : q[appState.trackIdx.clamp(0, q.length - 1)];
  final title = t?.title ?? '';
  if (w == null || title.isEmpty) {
    _media3Hidden = hideCard;
    _media3ArtworkLoadKey = '';
    AndroidMedia3.clearSession();
    return;
  }
  final artworkUrl = w.coverUrl;
  final artworkKey = '${w.rj}\n${artworkUrl ?? ''}';
  // 首次有播放内容时才启动媒体会话服务（避免启动即拉前台服务）；
  // 从「隐藏卡片」切回显示时若服务已被系统回收，重新拉起
  if (!_media3SessionStarted || (_media3Hidden && !hideCard)) {
    _media3SessionStarted = true;
    AndroidMedia3.ensureSession();
  }
  _media3Hidden = hideCard;
  AndroidMedia3.updateState(
    isPlaying: AppPlayer.instance.isNowPlaying,
    positionMs: AppPlayer.instance.currentPosition * 1000,
    durationMs: AppPlayer.instance.currentDuration * 1000,
    title: title,
    artist: w.title,
    artworkKey: artworkKey,
    mediaId: w.rj,
    hideCard: hideCard,
    logoCover: appState.notifCover,
  );
  final shouldLoadArtwork =
      !hideCard &&
      !appState.notifCover &&
      artworkUrl != null &&
      artworkUrl.isNotEmpty;
  final loadKey = shouldLoadArtwork ? artworkKey : '';
  if (_media3ArtworkLoadKey != loadKey) {
    _media3ArtworkLoadKey = loadKey;
    if (shouldLoadArtwork) {
      unawaited(_cacheMedia3Artwork(w.rj, artworkKey, artworkUrl));
    }
  }
}

/// 复用 Rust 网络层下载封面，交给原生层的是本地缓存路径而非远程 URL。
/// 这样私有服务器的鉴权和 Rust 的 TLS 兼容策略也会作用于媒体卡片封面。
Future<void> _cacheMedia3Artwork(
  String mediaId,
  String artworkKey,
  String artworkUrl,
) async {
  try {
    final bytes = await apiGetBytes(url: artworkUrl);
    if (_media3ArtworkLoadKey != artworkKey || bytes.isEmpty) return;
    final cacheDir = await getTemporaryDirectory();
    final file = File(
      '${cacheDir.path}${Platform.pathSeparator}kikoeta-media-artwork-${_stableArtworkId(artworkKey)}.img',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (_media3ArtworkLoadKey != artworkKey) return;
    await AndroidMedia3.updateArtwork(
      mediaId: mediaId,
      artworkKey: artworkKey,
      artworkPath: file.path,
    );
  } catch (_) {
    // 封面失败不能影响播放；系统继续显示无封面的标准媒体卡片。
  }
}

int _stableArtworkId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = (hash ^ unit) * 0x01000193 & 0x7fffffff;
  }
  return hash;
}

/// 绑定播放事件与全局状态变化 → 同步 MediaSession
void _bindMedia3Sync() {
  AppPlayer.instance.playing.listen((_) => _syncMedia3State());
  AppPlayer.instance.position.listen((d) {
    if (d - _lastMedia3Pos >= 5) {
      _lastMedia3Pos = d;
      _syncMedia3State();
    }
  });
  appState.addListener(() {
    final now = DateTime.now();
    // 隐藏卡片开关必须立即刷新，不能被常规状态同步节流吞掉。
    final hideCardChanged = appState.lsCover != _media3Hidden;
    if (hideCardChanged ||
        now.difference(_lastMedia3Sync).inMilliseconds > 1000) {
      _lastMedia3Sync = now;
      _syncMedia3State();
    }
  });
}

final AppState appState = AppState();

String? _persistedPlaybackTrack;
int _persistedPlaybackPosition = 0;

String? _playbackTrackKey() {
  if (appState.currentWork == null || appState.queue.isEmpty) return null;
  final index = appState.trackIdx.clamp(0, appState.queue.length - 1).toInt();
  final track = appState.queue[index];
  return '${appState.currentWork!.rj}|${track.path}|${track.url ?? ''}';
}

/// 播放器是全局单例，不能依赖 PlayerPage 的生命周期保存进度。
/// 位置流持续落盘，应用被系统直接终止时也只会损失最近几秒。
void _bindPlaybackPersistence() {
  _persistedPlaybackTrack = _playbackTrackKey();
  _persistedPlaybackPosition = appState.resumePosition;
  appState.addListener(_persistPlaybackTrackChange);
  AppPlayer.instance.position.listen(_persistPlaybackPositionTick);
  AppPlayer.instance.playing.listen((playing) {
    if (!playing) {
      _persistPlaybackPositionTick(
        AppPlayer.instance.currentPosition,
        force: true,
      );
    }
  });
}

void _persistPlaybackTrackChange() {
  final key = _playbackTrackKey();
  if (key == _persistedPlaybackTrack) return;
  _persistedPlaybackTrack = key;
  _persistedPlaybackPosition = 0;
  if (key == null) return;
  // 切歌后立即保存曲目和从零开始的位置，避免异常退出恢复到旧曲目/旧进度。
  appState.resumePosition = 0;
  appState.savePlayState();
}

void _persistPlaybackPositionTick(int position, {bool force = false}) {
  final key = _playbackTrackKey();
  if (key == null) return;
  if (key != _persistedPlaybackTrack) _persistPlaybackTrackChange();
  // 启动恢复尚未打开媒体时，播放器会先发出位置 0，不能覆盖已保存的进度。
  if (!AppPlayer.instance.opened && !appState.playing && position == 0) {
    return;
  }
  if (!force && position <= 0) return;
  if (!force && (position - _persistedPlaybackPosition).abs() < 5) return;
  _persistedPlaybackPosition = position;
  appState.resumePosition = position;
  appState.savePlayState();
}

class KikoetaApp extends StatefulWidget {
  const KikoetaApp({super.key});

  @override
  State<KikoetaApp> createState() => _KikoetaAppState();
}

/// 仅监听 MaterialApp 自身依赖的状态（主题模式 / 登录态 / UI 缩放）。
/// 其余状态变化由各页面自行监听并局部重建，
/// 避免每次 notify()（音量拖动、播放/暂停、收藏等）都重建整棵应用树导致掉帧。
class _KikoetaAppState extends State<KikoetaApp> with WidgetsBindingObserver {
  late ThemeMode _themeMode;
  late bool _loginRequired;
  late int _uiScalePercent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = appState.themeMode;
    _loginRequired = appState.loginRequired;
    _uiScalePercent = appState.uiScalePercent;
    appState.addListener(_onChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appState.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _persistPlaybackPositionTick(
        AppPlayer.instance.currentPosition,
        force: true,
      );
    }
  }

  void _onChanged() {
    if (_themeMode == appState.themeMode &&
        _loginRequired == appState.loginRequired &&
        _uiScalePercent == appState.uiScalePercent) {
      return;
    }
    _themeMode = appState.themeMode;
    _loginRequired = appState.loginRequired;
    _uiScalePercent = appState.uiScalePercent;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.fromView(
      view: View.of(context),
      child: _UiScale(scale: _uiScalePercent / 100, child: _buildApp()),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'Kikoeta',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      navigatorKey: appNavigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _themeMode,
      // 未登录 one 站且未配置自建服务器时，只显示登录页
      home: _loginRequired ? LoginPage(app: appState) : Shell(app: appState),
      routes: {
        '/work': (ctx) => WorkPage(
          app: appState,
          work: ModalRoute.of(ctx)!.settings.arguments as Work,
        ),
        '/player': (_) => PlayerPage(app: appState),
        '/settings': (_) => SettingsPage(app: appState),
      },
    );
  }
}

/// 以虚拟逻辑视口缩放整个 Flutter 界面，保证文字、间距、图标和命中区域同比例变化。
/// 桌面歌词由独立原生窗口绘制，不在此组件树内，因此不会受到影响。
class _UiScale extends StatelessWidget {
  final double scale;
  final Widget child;

  const _UiScale({required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (scale == 1) return child;
    final virtualMedia = media.copyWith(
      size: Size(media.size.width / scale, media.size.height / scale),
      padding: _divideInsets(media.padding, scale),
      viewPadding: _divideInsets(media.viewPadding, scale),
      viewInsets: _divideInsets(media.viewInsets, scale),
      systemGestureInsets: _divideInsets(media.systemGestureInsets, scale),
    );
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: virtualMedia.size.width,
          height: virtualMedia.size.height,
          child: MediaQuery(data: virtualMedia, child: child),
        ),
      ),
    );
  }

  EdgeInsets _divideInsets(EdgeInsets value, double divisor) =>
      EdgeInsets.fromLTRB(
        value.left / divisor,
        value.top / divisor,
        value.right / divisor,
        value.bottom / divisor,
      );
}

class Shell extends StatefulWidget {
  final AppState app;
  const Shell({super.key, required this.app});

  @override
  State<Shell> createState() => _ShellState();
}

/// Shell 只在自己的渲染依赖变化时重建（tab、搜索遮罩、迷你播放器内容），
/// 其余 notify（音量、收藏、首页数据加载等）不再触发整个 Shell/页面子树重建。
class _ShellState extends State<Shell> {
  late String _sig;

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    _sig = _computeSig();
    app.addListener(_onChanged);
  }

  @override
  void dispose() {
    app.removeListener(_onChanged);
    super.dispose();
  }

  String _computeSig() =>
      '${app.tab}|${app.searchExpanded}|${app.playing}|${app.hasQueue}|'
      '${app.trackIdx}|${app.queue.length}|${app.playWork?.rj ?? ''}';

  void _onChanged() {
    final s = _computeSig();
    if (s != _sig) {
      _sig = s;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final content = Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                // 避让状态栏（Android edge-to-edge 下 UI 不再被状态栏遮挡）
                top: true,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: IndexedStack(
                    index: app.tab,
                    children: [
                      HomePage(app: app),
                      FavoritesPage(app: app),
                      MorePage(app: app),
                    ],
                  ),
                ),
              ),
            ),
            if (app.playing || app.hasQueue)
              Positioned(
                left: 10,
                right: 10,
                // 竖屏贴近底栏，宽屏（侧边导航）贴底
                bottom: wide ? 12 : 8,
                child: MiniPlayer(app: app),
              ),
          ],
        );

        final scaffold = wide
            ? Scaffold(
                body: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: NavigationRail(
                        selectedIndex: app.tab,
                        onDestinationSelected: (i) {
                          app.selectTab(i);
                          app.setSearchExpanded(false);
                        },
                        backgroundColor: p.surface,
                        indicatorColor: p.accent.withValues(alpha: .14),
                        selectedIconTheme: IconThemeData(color: p.accent),
                        unselectedIconTheme: IconThemeData(color: p.dim),
                        selectedLabelTextStyle: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          color: p.dim,
                          fontSize: 12,
                        ),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('首页'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.favorite_border),
                            selectedIcon: Icon(Icons.favorite),
                            label: Text('收藏'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.more_horiz),
                            label: Text('更多'),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: p.line),
                    Expanded(child: content),
                  ],
                ),
              )
            : Scaffold(
                body: content,
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: app.tab,
                  onTap: (i) {
                    app.selectTab(i);
                    app.setSearchExpanded(false);
                  },
                  backgroundColor: p.tabbar,
                  selectedItemColor: p.accent,
                  unselectedItemColor: p.dim,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: '首页',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.favorite_border),
                      activeIcon: Icon(Icons.favorite),
                      label: '收藏',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz),
                      label: '更多',
                    ),
                  ],
                ),
              );

        return Stack(
          children: [
            scaffold,
            // 搜索展开时整窗变暗（覆盖导航栏/迷你播放器/边缘），点击任意处仅收起
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !app.searchExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: app.searchExpanded ? 1 : 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => app.setSearchExpanded(false),
                    child: Container(
                      color: Colors.black.withValues(alpha: .16),
                    ),
                  ),
                ),
              ),
            ),
            // 首页搜索栏浮在遮罩之上，保持可交互
            if (app.tab == 0)
              Positioned(
                top: 0,
                left: wide ? 80 + 1 + 16 : 16,
                right: 16,
                child: SafeArea(
                  // 避让状态栏后，66 = 6 顶部内边距 + 48 标题栏 + 12 间距
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 66),
                    child: Material(
                      color: Colors.transparent,
                      child: HomeSearchBar(app: app),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
