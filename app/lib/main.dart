import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
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
import 'services/sleep_timer.dart';
import 'services/clipboard_watcher.dart';
import 'services/desktop_lyrics_overlay.dart';
import 'services/android_audio.dart';
import 'services/android_lyrics_overlay.dart';
import 'services/android_media3.dart';
import 'services/android_notification.dart';
import 'services/lyrics_hub.dart';
import 'theme.dart';
import 'widgets.dart';

final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.init();
  await appState.loadFromRust();
  // 安卓音频控制：耳机拔出/焦点丢失 → 暂停播放
  AndroidAudio.init();
  AndroidAudio.onPauseRequested = () {
    AppPlayer.instance.player.pause();
  };
  if (!kIsWeb && Platform.isAndroid) {
    AndroidAudio.setEarPause(appState.earPause);
    AndroidAudio.setIgnoreAudioFocus(appState.ignoreAudioFocus);
  }
  MediaKit.ensureInitialized();
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
  // 定时关闭：全局计时（播放器页关闭时也生效）
  SleepTimer.start(appState);
  runApp(const KikoetaApp());
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
    AndroidLyricsOverlay.instance.init();
    appState.addListener(_syncAndroidLyrics);
    _syncAndroidLyrics();
  }
  LyricsHub.instance.start();
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

// ---------------- Jetpack Media3 桥接（锁屏/通知媒体控制） ----------------

int _lastMedia3Pos = -1;
DateTime _lastMedia3Sync = DateTime.fromMillisecondsSinceEpoch(0);
bool _media3SessionStarted = false;
// 「不显示通知栏媒体卡片」开关的上次状态（用于切回显示时重新拉起会话服务）
bool _media3Hidden = false;

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
  final w = appState.currentWork;
  final q = appState.queue;
  final t = q.isEmpty ? null : q[appState.trackIdx.clamp(0, q.length - 1)];
  final title = t?.title ?? '';
  if (w == null || title.isEmpty) {
    AndroidMedia3.clearSession();
    return;
  }
  final hideCard = appState.lsCover;
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
    artworkUrl: w.coverUrl,
    mediaId: w.rj,
    hideCard: hideCard,
    logoCover: appState.notifCover,
  );
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
    if (now.difference(_lastMedia3Sync).inMilliseconds > 1000) {
      _lastMedia3Sync = now;
      _syncMedia3State();
    }
  });
}

final AppState appState = AppState();

class KikoetaApp extends StatelessWidget {
  const KikoetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kikoeta',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: appMessengerKey,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: appState.themeMode,
          // 未登录 one 站且未配置自建服务器时，只显示登录页
          home: appState.loginRequired
              ? LoginPage(app: appState)
              : Shell(app: appState),
          routes: {
            '/work': (ctx) => WorkPage(
              app: appState,
              work: ModalRoute.of(ctx)!.settings.arguments as Work,
            ),
            '/player': (_) => PlayerPage(app: appState),
            '/settings': (_) => SettingsPage(app: appState),
          },
        );
      },
    );
  }
}

class Shell extends StatelessWidget {
  final AppState app;
  const Shell({super.key, required this.app});

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
                          app.tab = i;
                          app.setSearchExpanded(false);
                          app.notify();
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
                    app.tab = i;
                    app.setSearchExpanded(false);
                    app.notify();
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
