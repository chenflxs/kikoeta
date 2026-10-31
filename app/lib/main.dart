import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'data.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/app_language.dart';
import 'pages/favorites_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/more_page.dart';
import 'pages/player_page.dart';
import 'pages/settings_page.dart';
import 'pages/work_page.dart';
import 'services/player_service.dart';
import 'services/settings_store.dart';
import 'services/app_data_service.dart';
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
import 'services/download_service.dart';
import 'services/lyrics_library_broadcast_service.dart';
import 'services/api_service.dart';
import 'services/theme_reveal.dart';
import 'src/rust/api/kikoeru_api.dart';
import 'theme.dart';
import 'navigation_page_stack.dart';
import 'widgets.dart';
import 'l10n/strings.dart';

final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.init();
  await DownloadManager.instance.init();
  await appState.loadFromRust();
  if (appState.lyricsLibraryBroadcastOn) {
    try {
      await LyricsLibraryBroadcastService.instance.start();
    } catch (_) {
      appState.setLyricsLibraryBroadcastOn(false);
    }
  }
  await UpdateService.initialize();
  // Windows 首次运行：自动创建桌面/开始菜单快捷方式（仅 release，幂等）
  ShortcutService.ensureShortcuts();
  // 安卓音频控制：耳机拔出/焦点丢失 → 暂停播放
  AndroidAudio.init();
  AndroidAudio.onPauseRequested = () {
    AppPlayer.instance.pause();
  };
  if (!kIsWeb && Platform.isAndroid) {
    AndroidAudio.setEarPause(appState.earPause);
    AndroidAudio.setIgnoreAudioFocus(appState.ignoreAudioFocus);
  }
  if (!kIsWeb && Platform.isWindows) {
    await WindowsTrayService.instance.init(appState);
  }
  MediaKit.ensureInitialized();
  await _bindPlaybackOptions();
  await AppPlayer.instance.setMediaCacheLimitMb(appState.mediaCacheLimitMb);
  // 在首次加载媒体前配置 Android 音频后端与输出缓冲，降低 UI 交互/后台
  // 调度波动引发的环境声变淡和爆音。
  if (!kIsWeb && Platform.isAndroid) {
    await AppPlayer.instance.configureAndroidAudioStability();
  }
  // Jetpack Media3：锁屏/通知媒体控制（桥接到 mpv；service 在首次播放时才启动）
  // 注意：必须放在 MediaKit.ensureInitialized() 之后（AppPlayer 依赖 media_kit）
  if (!kIsWeb && Platform.isAndroid) {
    AndroidMedia3.init();
    AndroidMedia3.onCommand = _media3Command;
    AndroidMedia3.onPlaybackRateChanged = (rate) {
      if (appState.playbackSpeedEnabled) appState.setPlaybackRate(rate);
    };
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
  initializeDataSync(appState);
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
      onClose: () => appState.setDesktopLyricsOn(false),
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
      text: line,
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
  if (appState.desktopLyricsOn && !appState.desktopLyricsTemporarilyHidden) {
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
bool _playbackShortcutRunning = false;

Future<bool> _openAppTrack(MediaNode track, {bool autoplay = true}) async {
  final work = appState.currentWork;
  final local = work == null
      ? null
      : DownloadManager.instance.localPathFor(
          server: ApiService.resolveBase(appState),
          work: work,
          node: track,
        );
  if (local != null) {
    await AppPlayer.instance.openLocalPath(local, autoplay: autoplay);
    return true;
  }
  final url = track.url;
  if (url == null || url.isEmpty) return false;
  await AppPlayer.instance.openMediaUrl(url, autoplay: autoplay);
  return true;
}

/// 当前获得焦点的文本框状态，没有则为 null。
EditableTextState? _focusedEditableTextState() {
  return FocusManager.instance.primaryFocus?.context
      ?.findAncestorStateOfType<EditableTextState>();
}

/// 在文本框光标处插入一个空格。
/// 走 [EditableTextState.userUpdateTextEditingValue]，inputFormatters、
/// maxLength、撤销栈和控制器回调都会照常生效。
void _insertSpaceAtCaret(EditableTextState state) {
  if (state.widget.readOnly) return;
  final value = state.textEditingValue;
  final text = value.text;
  final selection = value.selection;
  final start = selection.isValid
      ? selection.start.clamp(0, text.length).toInt()
      : text.length;
  final end = selection.isValid
      ? selection.end.clamp(0, text.length).toInt()
      : text.length;
  state.userUpdateTextEditingValue(
    value.copyWith(
      text: text.replaceRange(start, end, ' '),
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    ),
    SelectionChangedCause.keyboard,
  );
}

/// 根级按键：文本框聚焦时把 Tab 当空格输入，否则只处理播放快捷键。
/// 返回 ignored 时按键会继续下发，不会丢字符。
KeyEventResult _handleRootKey(int keyId, KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final textState = _focusedEditableTextState();
  if (textState != null) {
    // 框架默认把 Tab 映射成 DoNothingAndStopPropagationTextIntent（只吞不输入），
    // 这里抢在 DefaultTextEditingShortcuts 之前把它换成插入空格。
    // 带修饰键的 Tab（如 Shift+Tab 反向遍历焦点）保持原样。
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      _insertSpaceAtCaret(textState);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  // 播放快捷键只在首次按下时触发，长按不连翻
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final toggle =
      LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey.space;
  if (event.logicalKey != toggle) return KeyEventResult.ignored;
  unawaited(_toggleAppPlaybackShortcut());
  return KeyEventResult.handled;
}

Future<void> _toggleAppPlaybackShortcut() async {
  if (_playbackShortcutRunning) return;
  _playbackShortcutRunning = true;
  try {
    if (appState.playing) {
      await AppPlayer.instance.pause();
      appState.playing = false;
    } else {
      if (appState.queue.isEmpty) return;
      if (!AppPlayer.instance.opened) {
        final index = appState.trackIdx
            .clamp(0, appState.queue.length - 1)
            .toInt();
        if (!await _openAppTrack(appState.queue[index], autoplay: false)) {
          return;
        }
        final resume = appState.resumePosition;
        if (resume > 0) {
          try {
            await AppPlayer.instance.player.seek(Duration(seconds: resume));
          } catch (_) {}
        }
        await AppPlayer.instance.applyEqualizer(
          enabled: appState.eqOn,
          gains: appState.eqGains,
        );
      }
      await AppPlayer.instance.play();
      appState.playing = true;
    }
    appState.notify();
  } catch (_) {
    // Playback errors are reported by the player service and should not
    // escape from a keyboard event handler.
  } finally {
    _playbackShortcutRunning = false;
  }
}

Future<void> _advanceAfterCompletion() async {
  final queue = appState.queue;
  if (_autoAdvancing || queue.isEmpty) return;
  _autoAdvancing = true;
  try {
    if (appState.playMode == 2) {
      await AppPlayer.instance.player.seek(Duration.zero);
      await AppPlayer.instance.play();
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
    if (!await _openAppTrack(queue[appState.trackIdx])) {
      appState.playing = false;
      appState.notify();
      return;
    }
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
// 最近一次已下发到原生层的封面隐私选项，用于让切换绕过常规状态同步节流。
bool _media3LogoCover = false;
double _media3PlaybackRate = 1.0;
bool _media3SpeedEnabled = false;
String _media3ArtworkLoadKey = '';

/// MediaSession 控制命令（Kotlin → Dart，mpv 执行）
void _media3Command(String action, int positionMs) {
  switch (action) {
    case 'play':
      AppPlayer.instance.play();
      break;
    case 'pause':
      AppPlayer.instance.pause();
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
  if (!appState.hasNextTrack) {
    _showMediaBoundaryToast(appL10n.playerAlreadyLastTrack);
    return;
  }
  appState.trackIdx++;
  appState.playing = true;
  appState.resumePosition = 0;
  appState.notify();
  if (await _openAppTrack(q[appState.trackIdx])) {
    try {
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
  if (!appState.hasPreviousTrack) {
    _showMediaBoundaryToast(appL10n.playerAlreadyFirstTrack);
    return;
  }
  appState.trackIdx--;
  appState.playing = true;
  appState.resumePosition = 0;
  appState.notify();
  if (await _openAppTrack(q[appState.trackIdx])) {
    try {
      AppPlayer.instance.applyEqualizer(
        enabled: appState.eqOn,
        gains: appState.eqGains,
      );
      appState.savePlayState();
    } catch (_) {}
  }
  _syncMedia3State();
}

void _showMediaBoundaryToast(String message) {
  appMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
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
    _media3LogoCover = appState.notifCover;
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
  _media3LogoCover = appState.notifCover;
  _media3PlaybackRate = appState.playbackRate;
  _media3SpeedEnabled = appState.playbackSpeedEnabled;
  AndroidMedia3.updateState(
    isPlaying: AppPlayer.instance.isNowPlaying,
    positionMs: AppPlayer.instance.currentPosition * 1000,
    durationMs: AppPlayer.instance.currentDuration * 1000,
    playbackRate: appState.playbackRate,
    playbackSpeedEnabled: appState.playbackSpeedEnabled,
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
    // 隐私相关开关必须立即刷新，不能被常规状态同步节流吞掉。
    final privacySettingChanged =
        appState.lsCover != _media3Hidden ||
        appState.notifCover != _media3LogoCover;
    final speedSettingChanged =
        appState.playbackRate != _media3PlaybackRate ||
        appState.playbackSpeedEnabled != _media3SpeedEnabled;
    if (privacySettingChanged ||
        speedSettingChanged ||
        now.difference(_lastMedia3Sync).inMilliseconds > 1000) {
      _lastMedia3Sync = now;
      _syncMedia3State();
    }
  });
}

final AppState appState = AppState();

/// 速度和声道不依赖播放器页面，切歌、后台播放和设置重置共用这份状态。
Future<void> _bindPlaybackOptions() async {
  var rate = appState.playbackRate;
  var channelMode = appState.audioChannelMode;
  await AppPlayer.instance.setPlaybackRate(rate);
  await AppPlayer.instance.setChannelMode(channelMode);
  appState.addListener(() {
    if (rate != appState.playbackRate) {
      rate = appState.playbackRate;
      unawaited(AppPlayer.instance.setPlaybackRate(rate));
    }
    if (channelMode != appState.audioChannelMode) {
      channelMode = appState.audioChannelMode;
      unawaited(AppPlayer.instance.setChannelMode(channelMode));
    }
  });
}

String? _persistedPlaybackTrack;

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
  if (key == null) return;
  // Until the new track opens, ignore stop/position events from the previous media.
  AppPlayer.instance.opened = false;
  // 切歌后立即保存曲目和从零开始的位置，避免异常退出恢复到旧曲目/旧进度。
  appState.resumePosition = 0;
  appState.savePlayState();
}

void _persistPlaybackPositionTick(int position, {bool force = false}) {
  final key = _playbackTrackKey();
  if (key == null) return;
  if (key != _persistedPlaybackTrack) _persistPlaybackTrackChange();
  appState.persistPlaybackPosition(
    position,
    mediaOpened: AppPlayer.instance.opened,
    force: force,
  );
}

class KikoetaApp extends StatefulWidget {
  const KikoetaApp({super.key});

  @override
  State<KikoetaApp> createState() => _KikoetaAppState();
}

/// 仅监听 MaterialApp 自身依赖的状态（主题模式 / 登录态 / UI 缩放 / 语言）。
/// 其余状态变化由各页面自行监听并局部重建，
/// 避免每次 notify()（音量拖动、播放/暂停、收藏等）都重建整棵应用树导致掉帧。
class _KikoetaAppState extends State<KikoetaApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// 圆形揭示时长：覆盖整个窗口的扩散，接近 Android 圆形揭示的观感
  static const Duration _revealDuration = Duration(milliseconds: 450);

  late ThemeMode _themeMode;
  late bool _loginRequired;
  late int _uiScalePercent;
  late String _uiLanguage;
  late int _playbackToggleShortcutKey;

  /// 根节点：抓「切换前外观」的截图用
  final GlobalKey _rootKey = GlobalKey();
  late final AnimationController _revealAnim = AnimationController(
    vsync: this,
    duration: _revealDuration,
  );
  late final CurvedAnimation _revealCurve = CurvedAnimation(
    parent: _revealAnim,
    curve: Curves.fastOutSlowIn,
  );
  ui.Image? _revealImage;
  Offset _revealOrigin = Offset.zero;
  int _revealSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = appState.themeMode;
    _loginRequired = appState.loginRequired;
    _uiScalePercent = appState.uiScalePercent;
    _uiLanguage = appState.uiLanguage;
    _playbackToggleShortcutKey = appState.playbackToggleShortcutKey;
    appState.addListener(_onChanged);
    _revealAnim.addStatusListener(_onRevealStatus);
    ThemeReveal.instance.bind(_switchThemeWithReveal);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appState.removeListener(_onChanged);
    _revealImage?.dispose();
    _revealCurve.dispose();
    _revealAnim.dispose();
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

  /// 跟随系统时，系统深浅色的变化同样从窗口中心扩散
  @override
  void didChangePlatformBrightness() {
    if (appState.themeMode == ThemeMode.system) {
      _switchThemeWithReveal(ThemeMode.system, null);
    }
  }

  /// 切换主题并播放圆形揭示动画。
  ///
  /// 顺序是关键：先抓「切换前」的截图，再让真实界面重建一次换成新主题，
  /// 最后把截图按不断扩大的圆裁掉。因此每帧只多一次贴图绘制，
  /// 没有第二棵控件树、也没有新旧外观同时插值的浑浊感。
  Future<void> _switchThemeWithReveal(
    ThemeMode mode,
    Offset? globalOrigin,
  ) async {
    final seq = ++_revealSeq;
    // 目标亮度与当前渲染亮度相同（例如深色切到「跟随系统」而系统本就是深色）时无需动画
    if (_targetBrightness(mode) == _renderedBrightness) {
      appState.setThemeMode(mode);
      return;
    }
    if (_revealImage != null) {
      // 上一次揭示还没播完：先撤掉贴图并等这一帧落地，避免把它拍进新截图
      _revealAnim.stop();
      _endReveal();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || seq != _revealSeq) return;
    }

    final image = await _captureRoot();
    if (!mounted || seq != _revealSeq) {
      image?.dispose(); // 期间又切了一次，交给最后一次
      return;
    }

    final box = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? Offset.zero
        : globalOrigin == null
        ? box.size.center(Offset.zero) // 设置页 / 跟随系统：窗口中心
        : box.globalToLocal(globalOrigin); // 首页按钮：按钮中心

    setState(() {
      _revealImage?.dispose();
      _revealImage = image;
      _revealOrigin = origin;
      _revealAnim.value = 0;
    });
    appState.setThemeMode(mode); // 真实界面只在这里重建一次
    if (image == null) return; // 截图失败：直接切换，不播放动画
    _revealAnim.forward();
  }

  /// 抓取根节点当前外观（切换前的样子），失败返回 null
  Future<ui.Image?> _captureRoot() async {
    final boundary =
        _rootKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.isEmpty) return null;
    try {
      // 上限 2.0：再高只是徒增一次读回的内存与耗时；
      // 乘 UI 缩放让贴图与屏幕像素一一对应，避免缩放后发虚
      final ratio = math.min(
        MediaQuery.devicePixelRatioOf(context) * _uiScalePercent / 100,
        2.0,
      );
      return await boundary.toImage(pixelRatio: ratio);
    } catch (_) {
      return null;
    }
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _endReveal();
  }

  void _endReveal() {
    final image = _revealImage;
    if (image == null) return;
    setState(() => _revealImage = null);
    image.dispose();
  }

  /// 该模式下应显示的亮度
  Brightness _targetBrightness(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  /// 当前这一帧实际渲染的亮度（跟随系统时以 MaterialApp 读到的平台亮度为准）
  Brightness get _renderedBrightness => switch (_themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => MediaQuery.platformBrightnessOf(context),
  };

  void _onChanged() {
    if (_themeMode == appState.themeMode &&
        _loginRequired == appState.loginRequired &&
        _uiScalePercent == appState.uiScalePercent &&
        _uiLanguage == appState.uiLanguage &&
        _playbackToggleShortcutKey == appState.playbackToggleShortcutKey) {
      return;
    }
    _themeMode = appState.themeMode;
    _loginRequired = appState.loginRequired;
    _uiScalePercent = appState.uiScalePercent;
    _uiLanguage = appState.uiLanguage;
    _playbackToggleShortcutKey = appState.playbackToggleShortcutKey;
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
      onGenerateTitle: (context) => context.l10n.appName,
      locale: AppLanguage.localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: AppLanguage.resolveLocales,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      navigatorKey: appNavigatorKey,
      builder: (context, child) {
        // 整个窗口（含 Windows 自定义标题栏）都在根 RepaintBoundary 里：
        // 主题切换的圆形揭示既要抓它的截图，也要盖住它
        return RepaintBoundary(
          key: _rootKey,
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) =>
                _handleRootKey(_playbackToggleShortcutKey, event),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (Platform.isWindows)
                  _windowsFrame(context, child)
                else
                  child ?? const SizedBox.shrink(),
                if (_revealImage != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ThemeRevealPainter(
                          image: _revealImage!,
                          origin: _revealOrigin,
                          progress: _revealCurve,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      // 主题切换交给圆形揭示动画，这里必须瞬时生效：否则被圆露出的区域
      // 会同步做 200ms 颜色插值，圆的边界上会看到新旧混色
      themeAnimationDuration: Duration.zero,
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

  /// Windows 窗口装饰：自定义标题栏 + 分割线 + 页面区
  Widget _windowsFrame(BuildContext context, Widget? child) {
    final theme = Theme.of(context);
    final titleBarColor = Color.lerp(
      theme.scaffoldBackgroundColor,
      theme.colorScheme.surface,
      0.5,
    )!;
    // 标题栏与内容之间的分割线：浅色下用极淡的深色发丝线，深色下用极淡的白色。
    // 颜色必须是「不透明」的：这一行下面没有任何不透明绘制，半透明色会被合成到
    // 未绘制的黑底上，最终仍是一条纯黑线。所以先和窗口底色混合成实色。
    final titleBarDividerColor = Color.alphaBlend(
      theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: .08)
          : Colors.black.withValues(alpha: .08),
      theme.scaffoldBackgroundColor,
    );
    return VirtualWindowFrame(
      child: Column(
        children: [
          SizedBox(
            height: kWindowCaptionHeight,
            child: WindowCaption(
              brightness: theme.brightness,
              backgroundColor: titleBarColor,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', width: 18, height: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Kikoeta',
                    style: TextStyle(
                      fontFamily: kAppFontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            // 必须给出宽度：无子节点的 ColoredBox 在松约束下会塌缩成 0 宽，
            // 那一行就没有任何绘制，露出窗口底色（黑线）就是这个原因。
            width: double.infinity,
            height: 1,
            child: ColoredBox(color: titleBarDividerColor),
          ),
          // 页面区必须裁剪：Windows 下 MaterialPageRoute 用的是 Zoom 转场，
          // 退场页会被放大到 1.05，不裁剪就会溢出盖住上面自定义标题栏的下沿
          Expanded(child: ClipRect(child: child ?? const SizedBox.shrink())),
        ],
      ),
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
                  child: NavigationPageStack(
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
                          fontFamily: kAppFontFamily,
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          fontFamily: kAppFontFamily,
                          color: p.dim,
                          fontSize: 12,
                        ),
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text(context.l10n.home),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.favorite_border),
                            selectedIcon: Icon(Icons.favorite),
                            label: Text(context.l10n.favorites),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.more_horiz),
                            label: Text(context.l10n.more),
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
                  items: [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: context.l10n.home,
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.favorite_border),
                      activeIcon: Icon(Icons.favorite),
                      label: context.l10n.favorites,
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz),
                      label: context.l10n.more,
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
