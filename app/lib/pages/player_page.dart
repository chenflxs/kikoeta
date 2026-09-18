import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' hide Track;

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/android_lyrics_overlay.dart';
import '../services/lyrics_hub.dart';
import '../services/lyrics_library_service.dart';
import '../services/player_service.dart';
import '../services/sleep_timer.dart';
import '../src/rust/api/textcodec.dart';
import '../src/rust/api/textconv.dart';
import '../sheets.dart';
import '../theme.dart';
import '../widgets.dart';

class PlayerPage extends StatefulWidget {
  final AppState app;
  const PlayerPage({super.key, required this.app});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  final PageController _pageCtrl = PageController();
  final List<LyricLine> _lyrics = [];
  final List<StreamSubscription> _subs = [];
  Timer? _sleepTimer;
  Timer? _wideChromeTimer;
  Timer? _wideCoverMenuTimer;
  int _pos = 0;
  int _dur = 0;
  int _lyricSeq = 0;
  final ScrollController _lyricScroll = ScrollController();
  final Map<int, GlobalKey> _lyricKeys = {};
  Timer? _lyricFollowTimer;
  bool _lyricAutoFollow = true;
  int _lyricScrollToken = 0;
  int _lastAutoIdx = -1;
  int _lrcOffsetMs = 0; // 字幕偏移（毫秒，正数表示歌词提前显示）
  String? _lyricSourceName; // 当前歌词来源（在线文件名 / 本地文件名）
  Size _lyricViewportSize = Size.zero;
  bool? _lyricViewportIsWide;
  bool _switching = false; // 切歌防抖：避免 completed 与手动点击重复触发
  DateTime? _lastAutoNext; // completed 自动跳转去重
  final Map<String, String> _convCache = {};
  late String _lastConv;
  late bool _lastLibraryAuto;
  late bool _lastAppPlaying;
  late int _lastTrackIdx;
  late String _lastUiStateSig;
  bool _opening = false; // 正在打开媒体
  bool _buffering = false; // 缓冲中
  int _lastSavedPos = 0; // 上次保存播放位置（节流）
  Future<void>? _restoreFuture;
  bool _wideLayoutActive = false;
  bool _wideChromeVisible = true;
  bool _wideCoverMenuVisible = false;
  bool _androidLandscapeStatusBarHidden = false;
  bool _appInForeground = true;

  Player get _player => AppPlayer.instance.player;
  bool get _opened => AppPlayer.instance.opened;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  Work get work => app.playWork!;
  MediaNode get track => app.queue[app.trackIdx];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appInForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lastConv = app.conv;
    _lastLibraryAuto = app.lyricsLibraryAuto;
    _lastAppPlaying = app.playing;
    _lastTrackIdx = app.trackIdx;
    _lastUiStateSig = _uiStateSig;
    _syncPlayerSnapshot();
    app.addListener(_onAppStateChanged);
    _subs.add(
      AppPlayer.instance.position.listen((d) {
        if (mounted) {
          // 值未变化时跳过重建（同一秒内重复 tick 不重绘整页）
          if (d != _pos) {
            final previousLyricIdx = _lyrics.isEmpty ? -1 : _currentLyricIdx();
            final nextLyricIdx = _lyrics.isEmpty ? -1 : _lyricIdxAt(d);
            final lyricChanged = nextLyricIdx != previousLyricIdx;
            if (lyricChanged && _lyricAutoFollow) {
              // 滚动与高亮渐变同时开始，避免先切换样式再等待帧后定位。
              _transitionToRenderedLyric(nextLyricIdx);
            }
            setState(() => _pos = d);
            if (lyricChanged && _lyricAutoFollow) {
              // 尚未布局时再请求定位；已启动的过渡不能被帧后 jumpTo 打断。
              _requestLyricAlignment();
            }
          } else {
            _maybeAutoScrollLyric();
          }
        }
        // 节流保存播放位置（每 5 秒），供重启恢复
        if (d - _lastSavedPos >= 5) {
          _lastSavedPos = d;
          app.resumePosition = d;
          app.savePlayState();
        }
      }),
    );
    _subs.add(
      AppPlayer.instance.duration.listen((d) {
        if (mounted) setState(() => _dur = d);
      }),
    );
    _subs.add(
      AppPlayer.instance.error.listen((e) {
        if (!mounted) return;
        app.playing = false;
        app.notify();
        setState(() {});
        _toast('播放失败：${_friendlyPlayError(e)}');
      }),
    );
    _subs.add(
      AppPlayer.instance.playing.listen((p) {
        if (p != app.playing) {
          app.playing = p;
          app.notify();
          if (!p) {
            // 暂停/停止：保存当前位置
            app.resumePosition = AppPlayer.instance.currentPosition;
            app.savePlayState();
          }
          if (mounted) setState(() {});
        }
      }),
    );
    _subs.add(
      AppPlayer.instance.buffering.listen((b) {
        if (mounted && b != _buffering) setState(() => _buffering = b);
      }),
    );
    _sleepTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkSleep(),
    );
    _applyVolume();
    // 重启恢复：有上次播放记录时打开并停在保存位置（默认暂停，不自动播放）
    final targetUrl = app.queue.isEmpty ? null : track.url;
    final needsOpen =
        !AppPlayer.instance.opened || AppPlayer.instance.openedUrl != targetUrl;
    if (!app.playing && app.queue.isNotEmpty && needsOpen) {
      final resume = app.resumePosition;
      _restoreFuture = _restorePlayback(resume);
    } else if (app.playing && app.queue.isNotEmpty && needsOpen) {
      // 全局播放器可能仍打开着上一部作品；目标媒体不同也必须重新打开。
      _openCurrent();
    }
    _loadLyrics();
  }

  Future<void> _restorePlayback(int resume) async {
    await _openCurrent(autoplay: false);
    if (!AppPlayer.instance.opened || resume <= 0) return;
    final target = Duration(seconds: resume);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _player.seek(target);
      } catch (_) {}
      if ((AppPlayer.instance.currentPosition - resume).abs() <= 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    // 打开媒体时可能先发出位置 0 的暂停事件，恢复定位完成后重新
    // 持久化一次，避免该初始化事件覆盖掉已保存的播放进度。
    app.resumePosition = resume;
    _lastSavedPos = resume;
    app.savePlayState();
    if (mounted) setState(() => _pos = resume);
  }

  Future<void> _loadLyrics() async {
    final seq = ++_lyricSeq;
    // 手动歌词只对当前曲目有效；切歌后回到自动匹配，不跨曲目沿用来源。
    _lyricSourceName = null;
    // 切歌后先清掉上一首的歌词；请求失败或新曲目无歌词时也不能保留旧内容。
    if (mounted) {
      setState(() {
        _lyrics.clear();
        _lyricKeys.clear();
        _lastAutoIdx = -1;
      });
    } else {
      _lyrics.clear();
      _lyricKeys.clear();
      _lastAutoIdx = -1;
    }
    LyricsHub.instance.setLyrics(const [], app.conv);
    final currentTrack = app.queue.isEmpty ? null : track;
    try {
      List<LyricLine> l = const [];
      if (app.lyricsLibraryAuto) {
        final library = await LyricsLibraryService.instance.matchingFiles(
          workId: work.rj,
          trackTitle: currentTrack?.title,
          trackPath: currentTrack?.path,
        );
        final trackKey = ApiService.lyricMatchKey(currentTrack?.title ?? '');
        final matched = library
            .where((file) => ApiService.lyricMatchKey(file.name) == trackKey)
            .toList();
        final candidates = matched.isNotEmpty
            ? matched
            : (library.length == 1 ? library : const <LyricsLibraryFile>[]);
        for (final file in candidates) {
          l = await LyricsLibraryService.instance.loadFile(file);
          if (l.isNotEmpty) {
            _lyricSourceName = file.relativePath;
            break;
          }
        }
      }
      if (l.isEmpty) {
        l = await ApiService.fetchLrc(
          app,
          work,
          trackTitle: currentTrack?.title,
          trackPath: currentTrack?.path,
          trackUrl: currentTrack?.url,
        );
      }
      if (mounted && seq == _lyricSeq && !_sameLyrics(l, _lyrics)) {
        setState(() {
          _lyrics
            ..clear()
            ..addAll(l);
          _lyricKeys.clear();
          _lastAutoIdx = -1;
        });
        LyricsHub.instance.setLyrics(_lyrics, app.conv);
      }
    } catch (_) {}
  }

  bool _sameLyrics(List<LyricLine> a, List<LyricLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].t != b[i].t || a[i].jp != b[i].jp || a[i].zh != b[i].zh) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _restoreAndroidStatusBar();
    WidgetsBinding.instance.removeObserver(this);
    app.removeListener(_onAppStateChanged);
    app.setDesktopLyricsTemporarilyHidden(false);
    for (final s in _subs) {
      s.cancel();
    }
    _sleepTimer?.cancel();
    _wideChromeTimer?.cancel();
    _wideCoverMenuTimer?.cancel();
    _lyricFollowTimer?.cancel();
    _lyricScroll.dispose();
    _pageCtrl.dispose();
    // 离开播放器页时保存播放位置（重启可恢复）
    if (app.queue.isNotEmpty) {
      app.resumePosition = AppPlayer.instance.currentPosition;
      app.savePlayState();
    }
    super.dispose();
  }

  void _onAppStateChanged() {
    final playingChanged = app.playing != _lastAppPlaying;
    _lastAppPlaying = app.playing;
    var needsRebuild = playingChanged;
    if (app.trackIdx != _lastTrackIdx) {
      _lastTrackIdx = app.trackIdx;
      // 自动续播在应用常驻层推进队列，和手动切歌一样重新匹配歌词。
      _loadLyrics();
      needsRebuild = true;
    }
    if (app.conv != _lastConv) {
      _lastConv = app.conv;
      _convCache.clear();
      _lastAutoIdx = -1;
      LyricsHub.instance.setConv(app.conv);
      needsRebuild = true;
    }
    if (app.lyricsLibraryAuto != _lastLibraryAuto) {
      _lastLibraryAuto = app.lyricsLibraryAuto;
      _loadLyrics();
      needsRebuild = true;
    }
    final uiStateSig = _uiStateSig;
    if (uiStateSig != _lastUiStateSig) {
      _lastUiStateSig = uiStateSig;
      needsRebuild = true;
    }
    if (needsRebuild && mounted) setState(() {});
  }

  /// 仅订阅播放器实际绘制的全局状态，避免无关的首页请求重绘播放器。
  String get _uiStateSig =>
      '${app.desktopLyricsOn}|${app.playMode}|${app.volume}|'
      '${app.volumeBoostLevel}|${app.sleepEndAt?.millisecondsSinceEpoch}|'
      '${app.queue.length}|${app.playWork?.rj ?? ''}|${app.lyricsLibraryAuto}';

  void _syncPlayerSnapshot({bool rebuild = false}) {
    final position = AppPlayer.instance.currentPosition;
    final duration = AppPlayer.instance.currentDuration;
    if (_pos == position && _dur == duration) return;
    if (rebuild && mounted) {
      setState(() {
        _pos = position;
        _dur = duration;
      });
      return;
    }
    _pos = position;
    _dur = duration;
  }

  Future<void> _openCurrent({bool autoplay = true}) async {
    final localPath = app.currentWork == null
        ? null
        : DownloadManager.instance.localPathFor(
            server: ApiService.resolveBase(app),
            work: app.currentWork!,
            node: track,
          );
    final url = track.url;
    if (localPath == null && url == null) {
      app.playing = false;
      app.notify();
      _toast('文件流需登录后可用');
      return;
    }
    if (mounted) setState(() => _opening = true);
    try {
      if (localPath != null) {
        await AppPlayer.instance.openLocalPath(localPath, autoplay: autoplay);
        _syncPlayerSnapshot(rebuild: true);
        _applyVolume();
        AppPlayer.instance.applyEqualizer(
          enabled: app.eqOn,
          gains: app.eqGains,
        );
      } else {
        await _openMedia(url!, autoplay: autoplay);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// 打开媒体（失败自动重试一次）
  Future<void> _openMedia(
    String url, {
    required bool autoplay,
    int attempt = 1,
  }) async {
    try {
      await AppPlayer.instance.openMediaUrl(url, autoplay: autoplay);
      _syncPlayerSnapshot(rebuild: true);
      _applyVolume();
      AppPlayer.instance.applyEqualizer(enabled: app.eqOn, gains: app.eqGains);
    } on TimeoutException {
      if (attempt < 2) {
        if (mounted) _toast('打开媒体超时，正在重试…');
        await Future.delayed(const Duration(seconds: 1));
        await _openMedia(url, autoplay: autoplay, attempt: attempt + 1);
      } else {
        app.playing = false;
        app.notify();
        _toast('打开媒体超时，请重试');
      }
    } catch (e) {
      if (attempt < 2) {
        if (mounted) _toast('打开失败，正在重试…');
        await Future.delayed(const Duration(seconds: 1));
        await _openMedia(url, autoplay: autoplay, attempt: attempt + 1);
      } else {
        app.playing = false;
        app.notify();
        _toast('无法打开媒体流：${_friendlyPlayError(e.toString())}');
      }
    }
  }

  /// 把底层播放错误映射为可读提示（本地代理 401/403、网络不通等）
  String _friendlyPlayError(String e) {
    final s = e.toLowerCase();
    if (s.contains('upstream error 401') || s.contains('upstream error 403')) {
      return '登录已失效，请重新登录后重试';
    }
    if (s.contains('upstream error')) return '服务器返回错误，请稍后重试';
    if (s.contains('failed to open') || s.contains('connection refused')) {
      return '无法连接媒体流，请检查网络后重试';
    }
    if (s.contains('127.0.0.1')) {
      return '媒体流代理异常，请重试';
    }
    return e;
  }

  void _next({bool auto = false}) {
    if (app.queue.isEmpty || _switching) return;
    if (auto) {
      final now = DateTime.now();
      // mpv 加载新文件时可能残留触发一次 completed，2 秒内忽略
      if (_lastAutoNext != null &&
          now.difference(_lastAutoNext!) < const Duration(seconds: 2)) {
        return;
      }
      _lastAutoNext = now;
    }
    // 单曲循环：播完重播当前曲目
    if (auto && app.playMode == 2) {
      _restartCurrent();
      return;
    }
    // 列表播放：最后一首播完停止
    if (auto && app.playMode == 0 && app.trackIdx == app.queue.length - 1) {
      // 定时关闭「播放完毕」模式：列表播完自动停止并关闭
      if (app.sleepMode == 'end' && app.sleepPlayEndArmed) {
        SleepTimer.triggerNow(app);
        return;
      }
      app.playing = false;
      app.notify();
      setState(() {});
      _toast('已播放完播放列表');
      return;
    }
    _switching = true;
    app.trackIdx = (app.trackIdx + 1) % app.queue.length;
    _pos = 0;
    _dur = 0;
    AppPlayer.instance.opened = false;
    _refreshLyricsForCurrentTrack();
    app.notify();
    setState(() {});
    // 自动跳转（播放结束）不依赖 playing 状态，强制打开下一首；
    // 手动切歌时若处于暂停则只换曲目，不自动播放
    if (auto || app.playing) {
      _openCurrent().whenComplete(() => _switching = false);
    } else {
      _switching = false;
    }
  }

  Future<void> _restartCurrent() async {
    _pos = 0;
    _dur = 0;
    setState(() {});
    try {
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      // seek 失败则重新打开当前曲目
      AppPlayer.instance.opened = false;
      _openCurrent();
    }
  }

  void _refreshLyricsForCurrentTrack() {
    // 先同步索引快照，避免紧随后的 app.notify() 重复发起同一匹配请求。
    _lastTrackIdx = app.trackIdx;
    _loadLyrics();
  }

  void _jumpTo(int idx) {
    if (idx == app.trackIdx) return;
    if (app.queue.isEmpty || _switching) return;
    _switching = true;
    app.trackIdx = idx;
    _pos = 0;
    _dur = 0;
    AppPlayer.instance.opened = false;
    _refreshLyricsForCurrentTrack();
    app.notify();
    setState(() {});
    if (app.playing) {
      _openCurrent().whenComplete(() => _switching = false);
    } else {
      _switching = false;
    }
  }

  void _prev() {
    if (app.queue.isEmpty || _switching) return;
    _switching = true;
    app.trackIdx = (app.trackIdx + app.queue.length - 1) % app.queue.length;
    _pos = 0;
    _dur = 0;
    AppPlayer.instance.opened = false;
    _refreshLyricsForCurrentTrack();
    app.notify();
    setState(() {});
    if (app.playing) {
      _openCurrent().whenComplete(() => _switching = false);
    } else {
      _switching = false;
    }
  }

  void _checkSleep() {
    final end = app.sleepEndAt;
    if (end == null || !DateTime.now().isAfter(end)) return;
    SleepTimer.check(app);
    if (mounted) setState(() {});
    _toast('已停止播放，系统接口已释放');
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _seekTo(int t) {
    _player.seek(Duration(seconds: t));
    setState(() => _pos = t);
    // 手动跳转（进度条/点歌词）后歌词立即跟随，不再等 3 秒
    _lyricAutoFollow = true;
    _lyricFollowTimer?.cancel();
    _lastAutoIdx = -1;
    _maybeAutoScrollLyric();
  }

  void _seekRelative(int delta) {
    final target = (_pos + delta).clamp(0, math.max(_dur, 1)).toInt();
    _player.seek(Duration(seconds: target));
    setState(() => _pos = target);
  }

  void _setVolumeMax(int max) {
    final p = _player.platform;
    if (p is NativePlayer) {
      unawaited(p.setProperty('volume-max', '$max'));
    }
  }

  void _applyVolume() {
    _setVolumeMax(app.volumeMax);
    unawaited(_player.setVolume(app.volume));
  }

  void _toggleBoost() {
    app.cycleVolumeBoost();
    _applyVolume();
    setState(() {});
  }

  Future<void> _togglePlayback() async {
    await _restoreFuture;
    if (!mounted) return;
    if (app.playing) {
      await _player.pause();
      app.playing = false;
    } else {
      if (_opened) {
        final resume = app.resumePosition;
        final current = AppPlayer.instance.currentPosition;
        if (resume > current + 1) {
          try {
            await _player.seek(Duration(seconds: resume));
          } catch (_) {}
        }
        await _player.play();
      } else {
        await _openCurrent();
      }
      app.playing = true;
    }
    app.notify();
    if (mounted) setState(() {});
  }

  LogicalKeyboardKey _shortcutKey(int keyId, LogicalKeyboardKey fallback) =>
      LogicalKeyboardKey.findKeyByKeyId(keyId) ?? fallback;

  void _setWideLayoutActive(bool active) {
    if (_wideLayoutActive == active) {
      _syncWideAndroidDesktopLyrics();
      return;
    }
    _wideLayoutActive = active;
    _syncWideAndroidDesktopLyrics();
    if (active) {
      _showWideChrome();
      return;
    }
    _wideChromeTimer?.cancel();
    _wideCoverMenuTimer?.cancel();
    if (_wideChromeVisible && !_wideCoverMenuVisible) return;
    setState(() {
      _wideChromeVisible = true;
      _wideCoverMenuVisible = false;
    });
  }

  void _showWideChrome() {
    _wideChromeTimer?.cancel();
    if (!_wideChromeVisible && mounted) {
      setState(() => _wideChromeVisible = true);
    }
    _wideChromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _wideLayoutActive) {
        setState(() => _wideChromeVisible = false);
      }
    });
  }

  void _showWideCoverMenu() {
    _wideCoverMenuTimer?.cancel();
    setState(() => _wideCoverMenuVisible = true);
    _wideCoverMenuTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _wideLayoutActive) {
        setState(() => _wideCoverMenuVisible = false);
      }
    });
  }

  void _hideWideCoverMenu() {
    _wideCoverMenuTimer?.cancel();
    if (_wideCoverMenuVisible) {
      setState(() => _wideCoverMenuVisible = false);
    }
  }

  void _runWideCoverAction(VoidCallback action) {
    _hideWideCoverMenu();
    action();
  }

  void _syncWideAndroidDesktopLyrics() {
    app.setDesktopLyricsTemporarilyHidden(
      Platform.isAndroid && _wideLayoutActive && _appInForeground,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _syncWideAndroidDesktopLyrics();
  }

  void _syncAndroidLandscapeStatusBar(Size size) {
    final hide = Platform.isAndroid && size.width > size.height;
    if (_androidLandscapeStatusBarHidden == hide) return;
    _androidLandscapeStatusBarHidden = hide;
    unawaited(
      hide
          ? SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
          : SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.manual,
              overlays: SystemUiOverlay.values,
            ),
    );
  }

  void _restoreAndroidStatusBar() {
    if (!_androidLandscapeStatusBarHidden) return;
    _androidLandscapeStatusBarHidden = false;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAndroidLandscapeStatusBar(media.size);
    });
    final wideMobile =
        (Platform.isAndroid || Platform.isIOS) &&
        media.size.height > 0 &&
        media.size.width / media.size.height >= 2;
    // 系统安全区未必包含屏幕圆角。长屏手机额外保留圆角余量，
    // 两侧使用相同边距，让刘海位于任意一侧时内容仍保持居中。
    final cornerInset = (media.size.shortestSide * .09).clamp(28.0, 44.0);
    final wideSideInset = math.max(
      cornerInset,
      math.max(media.viewPadding.left, media.viewPadding.right),
    );
    final w = app.playWork;
    if (w == null || app.queue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setWideLayoutActive(false);
      });
      return Scaffold(
        backgroundColor: p.bg,
        body: Center(
          child: Text('暂无播放内容', style: TextStyle(fontSize: 14, color: p.dim)),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          _shortcutKey(app.playbackToggleShortcutKey, LogicalKeyboardKey.space),
        ): () {
          unawaited(_togglePlayback());
        },
        SingleActivator(
          _shortcutKey(
            app.playbackPreviousShortcutKey,
            LogicalKeyboardKey.pageUp,
          ),
        ): _prev,
        SingleActivator(
          _shortcutKey(
            app.playbackNextShortcutKey,
            LogicalKeyboardKey.pageDown,
          ),
        ): _next,
        SingleActivator(
          _shortcutKey(
            app.playbackSeekBackwardShortcutKey,
            LogicalKeyboardKey.arrowLeft,
          ),
        ): () =>
            _seekRelative(-10),
        SingleActivator(
          _shortcutKey(
            app.playbackSeekForwardShortcutKey,
            LogicalKeyboardKey.arrowRight,
          ),
        ): () =>
            _seekRelative(10),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: p.bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.3,
                        colors: [
                          p.accent.withValues(alpha: .16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                minimum: wideMobile
                    ? EdgeInsets.fromLTRB(wideSideInset, 12, wideSideInset, 12)
                    : EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final screenSize = MediaQuery.sizeOf(context);
                    final useWideLayout =
                        screenSize.height > 0 &&
                        screenSize.width / screenSize.height >= 2;
                    final routeIsCurrent =
                        ModalRoute.of(context)?.isCurrent ?? true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _setWideLayoutActive(useWideLayout && routeIsCurrent);
                      }
                    });
                    if (useWideLayout) return _wideLandscape();
                    if (c.maxWidth >= 700) return _landscape();
                    return _portrait();
                  },
                ),
              ),
              if (_opening || _buffering)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 竖屏：左滑进歌词页，右滑回封面页 ----------
  Widget _portrait() {
    return ScrollConfiguration(
      behavior: const _PlayerPageScrollBehavior(),
      child: PageView(
        controller: _pageCtrl,
        onPageChanged: _onPlayerPageChanged,
        children: [
          Column(
            children: [
              _topBar(showControls: false),
              Expanded(child: _coverBody(alignLeft: false)),
            ],
          ),
          _lyricsPanel(showTopBar: true),
        ],
      ),
    );
  }

  void _onPlayerPageChanged(int page) {
    if (page != 1) return;
    // PageView 保留歌词页的 ScrollPosition。重新进入时必须以当前播放行
    // 为准，不能把上次离开时的 offset 当成已经完成的自动定位。
    _lyricAutoFollow = true;
    _lyricFollowTimer?.cancel();
    _lastAutoIdx = -1;
    _requestLyricAlignment(animated: false, force: true);
  }

  // ---------- 横屏：左封面上 + 下控件，右歌词 ----------
  Widget _landscape() {
    return Column(
      children: [
        _topBar(showControls: true),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _coverBody(alignLeft: true)),
              VerticalDivider(width: 1, thickness: 1, color: p.line),
              Expanded(flex: 6, child: _lyricsPanel(showTopBar: false)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- 超宽横屏（宽高比 >= 2:1）：左封面，右信息与歌词 ----------
  Widget _wideLandscape() {
    final size = MediaQuery.sizeOf(context);
    final horizontalInset = (size.width * .045).clamp(24.0, 80.0);
    final columnGap = (size.width * .035).clamp(24.0, 64.0);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _showWideChrome(),
      onPointerHover: (_) => _showWideChrome(),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalInset,
              24,
              horizontalInset,
              20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 9, child: _wideCoverColumn()),
                SizedBox(width: columnGap),
                Expanded(flex: 11, child: _wideInfoColumn()),
              ],
            ),
          ),
          Positioned(
            left: 8,
            top: 4,
            child: _wideChromeButton(
              visible: _wideChromeVisible,
              tooltip: '返回',
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            right: 8,
            top: 4,
            child: _wideChromeButton(
              visible: _wideChromeVisible,
              tooltip: '更多',
              icon: Icons.more_horiz,
              onPressed: _showLyricSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideChromeButton({
    required bool visible,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: p.surface.withValues(alpha: .72),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, size: 24, color: p.text),
          ),
        ),
      ),
    );
  }

  Widget _wideCoverColumn() {
    return LayoutBuilder(
      builder: (context, c) {
        final coverSize = math.min(
          c.maxWidth * .86,
          math.max(0.0, c.maxHeight - 74),
        );
        return Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox.square(
                  dimension: coverSize,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _wideCoverMenuVisible
                        ? _wideCoverMenu(coverSize)
                        : GestureDetector(
                            key: const ValueKey('wide-cover'),
                            onTap: _showWideCoverMenu,
                            child: CoverArt(work: work, radius: 18),
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 58,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _pos.toDouble().clamp(0, math.max(_dur, 1).toDouble()),
                  max: math.max(_dur, 1).toDouble(),
                  activeColor: p.text,
                  inactiveColor: p.track,
                  onChanged: (v) => _seekTo(v.round()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _wideCoverMenu(double size) {
    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.article_outlined,
        '作品详情',
        () => Navigator.of(context).push(buildWorkRoute(app, work)),
      ),
      (Icons.queue_music, '播放列表', _showQueue),
      (Icons.equalizer_outlined, '均衡器', () => showEqSheet(context, app)),
      (Icons.timer_outlined, '定时关闭', () => showSleepSheet(context, app)),
    ];
    return Material(
      key: const ValueKey('wide-cover-menu'),
      color: p.surface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(
              child: InkWell(
                onTap: () => _runWideCoverAction(actions[i].$3),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        actions[i].$1,
                        size: size < 230 ? 18 : 21,
                        color: p.text,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        actions[i].$2,
                        style: TextStyle(
                          color: p.text,
                          fontSize: size < 230 ? 12.5 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i != actions.length - 1)
              Divider(height: 1, indent: 24, endIndent: 24, color: p.line),
          ],
        ],
      ),
    );
  }

  Widget _wideInfoColumn() {
    final title = track.title.replaceAll(
      RegExp(r'\.(mp3|wav|flac|m4a|aac|ogg|opus)$'),
      '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: p.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${work.title} · ${work.circle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.muted, fontSize: 13),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _wideLyricsPanel(),
          ),
        ),
        SizedBox(
          height: 58,
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 360;
              final sideButtonSize = compact ? 40.0 : 48.0;
              return Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_fmt(_pos)}/${_dur > 0 ? _fmt(_dur) : '--:--'}',
                        style: TextStyle(color: p.muted, fontSize: 16),
                      ),
                    ),
                  ),
                  if (!compact)
                    IconButton(
                      onPressed: _cyclePlayMode,
                      tooltip: _playModeLabel,
                      icon: Icon(
                        app.playMode == 1
                            ? Icons.repeat
                            : app.playMode == 2
                            ? Icons.repeat_one
                            : Icons.playlist_play,
                        size: 21,
                        color: app.playMode == 0 ? p.dim : p.accent,
                      ),
                    ),
                  SizedBox.square(
                    dimension: sideButtonSize,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _prev,
                      icon: Icon(Icons.skip_previous, size: 30, color: p.text),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox.square(
                    dimension: compact ? 52 : 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.text,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: p.text.withValues(alpha: .14),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _togglePlayback,
                        icon: Icon(
                          app.playing ? Icons.pause : Icons.play_arrow,
                          size: 34,
                          color: p.bg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox.square(
                    dimension: sideButtonSize,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _next,
                      icon: Icon(Icons.skip_next, size: 30, color: p.text),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _wideLyricsPanel() {
    if (_lyrics.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('暂无歌词', style: TextStyle(fontSize: 14, color: p.dim)),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        _trackLyricViewport(Size(c.maxWidth, c.maxHeight), isWide: true);
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0x40FFFFFF),
                Colors.white,
                Colors.white,
                Color(0x40FFFFFF),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [0, .06, .18, .34, .66, .82, .94, 1],
            ).createShader(bounds),
            child: _buildLyricScrollView(
              viewportHeight: c.maxHeight,
              isWide: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricScrollView({
    required double viewportHeight,
    required bool isWide,
  }) {
    final currentIdx = _currentLyricIdx();
    final edgeSpace = math.max(viewportHeight * .5, 40.0);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleLyricScrollNotification,
      child: SingleChildScrollView(
        controller: _lyricScroll,
        child: Column(
          children: [
            SizedBox(height: edgeSpace),
            for (var i = 0; i < _lyrics.length; i++)
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  key: _lyricKeys.putIfAbsent(i, GlobalKey.new),
                  onTap: () => _seekTo(_lyrics[i].t),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: isWide ? 0 : 20,
                    ),
                    child: _buildLyricLineText(
                      _displayLyric(_lyrics[i]),
                      current: i == currentIdx,
                      isWide: isWide,
                    ),
                  ),
                ),
              ),
            SizedBox(height: edgeSpace),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricLineText(
    String text, {
    required bool current,
    required bool isWide,
  }) {
    final alignment = isWide ? Alignment.centerLeft : Alignment.center;
    final textAlign = isWide ? TextAlign.start : TextAlign.center;
    final activeStyle = TextStyle(
      fontSize: isWide ? 18 : 16,
      fontWeight: FontWeight.w700,
      color: p.text,
    );
    final inactiveStyle = TextStyle(
      fontSize: isWide ? 15 : 14.5,
      fontWeight: FontWeight.normal,
      color: p.dim,
    );
    return Stack(
      alignment: alignment,
      children: [
        // 每一行始终按高亮样式预留空间，切换高亮时行高和换行不变。
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: Text(text, textAlign: textAlign, style: activeStyle),
          ),
        ),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          style: current ? activeStyle : inactiveStyle,
          child: Text(text, textAlign: textAlign),
        ),
      ],
    );
  }

  bool _handleLyricScrollNotification(ScrollNotification notification) {
    final userDriven =
        notification is ScrollStartNotification &&
            notification.dragDetails != null ||
        notification is ScrollUpdateNotification &&
            notification.dragDetails != null ||
        notification is OverscrollNotification &&
            notification.dragDetails != null;
    if (userDriven) _onLyricUserScroll();
    return false;
  }

  void _trackLyricViewport(Size size, {required bool isWide}) {
    final changed =
        (_lyricViewportSize.width - size.width).abs() > .5 ||
        (_lyricViewportSize.height - size.height).abs() > .5 ||
        _lyricViewportIsWide != isWide;
    if (changed) {
      _lyricViewportSize = size;
      _lyricViewportIsWide = isWide;
      _lastAutoIdx = -1;
    }
    if (changed || _lastAutoIdx < 0) {
      _requestLyricAlignment(animated: false, force: true);
    }
  }

  Widget _topBar({bool showControls = true}) {
    return SizedBox(
      height: kMinInteractiveDimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.keyboard_arrow_down, size: 26),
            ),
          ),
          const Text(
            '正在播放',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          // 桌面歌词/更多仅出现在歌词页右上（封面页通过左右滑动进入歌词页）
          if (showControls)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _toggleDesktopLyrics,
                    tooltip: '桌面歌词',
                    icon: Icon(
                      app.desktopLyricsOn
                          ? Icons.lyrics
                          : Icons.lyrics_outlined,
                      size: 22,
                      color: app.desktopLyricsOn ? p.accent : null,
                    ),
                  ),
                  IconButton(
                    onPressed: _showLyricSettings,
                    icon: const Icon(Icons.more_horiz, size: 22),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleDesktopLyrics() async {
    if (!app.desktopLyricsOn && Platform.isAndroid) {
      final ok = await AndroidLyricsOverlay.instance.requestPermission();
      if (!ok) {
        if (mounted) _toast('未授予悬浮窗权限，桌面歌词无法显示');
        return; // 保持关闭
      }
    }
    app.setDesktopLyricsOn(!app.desktopLyricsOn);
    LyricsHub.instance.setLyrics(_lyrics, app.conv);
  }

  Widget _coverBody({required bool alignLeft}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: alignLeft ? 24 : 20),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final size = math.min(c.maxWidth * 0.8, c.maxHeight * 0.9);
                const btn = 44.0;
                const edgePad = 10.0;
                // 按钮中心贴近窗口左右边缘时的偏移
                final edgeOffset = c.maxWidth / 2 - edgePad - btn / 2;
                // 封面上的最小落点（靠近封面左右边）
                final minOffset = size * 0.34;
                // 按钮刚好在封面外侧时需要的偏移
                final clearOffset = size / 2 + 16;
                final t = ((edgeOffset - minOffset) / (clearOffset - minOffset))
                    .clamp(0.0, 1.0);
                final offset = minOffset + (edgeOffset - minOffset) * t;
                final half = math.max(c.maxWidth / 2, 1.0);
                final ax = (offset / half).clamp(0.0, 1.0);
                final cover = SizedBox(
                  width: size,
                  height: size,
                  child: CoverArt(work: work, radius: 14),
                );
                final left = _seekCircle(
                  Icons.replay_10,
                  () => _seekRelative(-10),
                );
                final right = _seekCircle(
                  Icons.forward_30,
                  () => _seekRelative(30),
                );
                return SizedBox(
                  width: c.maxWidth,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      cover,
                      AnimatedAlign(
                        alignment: Alignment(-ax, 0),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: left,
                      ),
                      AnimatedAlign(
                        alignment: Alignment(ax, 0),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: right,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Text(
            track.title.replaceAll(
              RegExp(r'\.(mp3|wav|flac|m4a|aac|ogg|opus)$'),
              '',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${work.title} · ${work.circle}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: SizedBox(
              height: 28,
              child: Slider(
                value: _pos.toDouble().clamp(0, math.max(_dur, 1).toDouble()),
                max: math.max(_dur, 1).toDouble(),
                activeColor: p.accent,
                inactiveColor: p.track,
                onChanged: (v) => _seekTo(v.round()),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_pos), style: TextStyle(fontSize: 11, color: p.dim)),
              Text(
                _dur > 0 ? _fmt(_dur) : '--:--',
                style: TextStyle(fontSize: 11, color: p.dim),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _controls(),
          const SizedBox(height: 2),
          _volumeControl(),
          const SizedBox(height: 10),
          _utils(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _controls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放模式：列表播放 -> 循环播放 -> 单曲循环 -> 列表播放
        IconButton(
          onPressed: _cyclePlayMode,
          icon: Icon(
            app.playMode == 1
                ? Icons.repeat
                : app.playMode == 2
                ? Icons.repeat_one
                : Icons.playlist_play,
            size: 20,
          ),
          color: app.playMode == 0 ? p.dim : p.accent,
          tooltip: _playModeLabel,
        ),
        IconButton(
          onPressed: _prev,
          icon: const Icon(Icons.skip_previous, size: 26),
          color: p.text,
        ),
        const SizedBox(width: 6),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [p.accent, p.accent2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: p.accent.withValues(alpha: .3), blurRadius: 30),
            ],
          ),
          child: IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              app.playing ? Icons.pause : Icons.play_arrow,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _next,
          icon: const Icon(Icons.skip_next, size: 26),
          color: p.text,
        ),
        // 播放列表
        IconButton(
          onPressed: _showQueue,
          icon: const Icon(Icons.queue_music, size: 20),
          color: p.dim,
          tooltip: '播放列表',
        ),
      ],
    );
  }

  String get _playModeLabel => switch (app.playMode) {
    1 => '循环播放',
    2 => '单曲循环',
    _ => '列表播放',
  };

  void _cyclePlayMode() {
    app.playMode = (app.playMode + 1) % 3;
    app.notify();
    setState(() {});
    _toast(_playModeLabel);
  }

  void _showQueue() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.sizeOf(context).height * 0.7,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.queue_music, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Text(
                    '播放列表（${app.queue.length}）',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, size: 18, color: p.dim),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.line),
            Expanded(
              child: app.queue.isEmpty
                  ? Center(
                      child: Text(
                        '播放列表为空',
                        style: TextStyle(fontSize: 13, color: p.dim),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: app.queue.length,
                      itemBuilder: (ctx, i) {
                        final n = app.queue[i];
                        final current = i == app.trackIdx;
                        return InkWell(
                          onTap: current
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _jumpTo(i);
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  current
                                      ? Icons.graphic_eq
                                      : Icons.music_note_outlined,
                                  size: 18,
                                  color: current ? p.accent : p.dim,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    n.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: current ? p.accent : p.text,
                                      fontWeight: current
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (current)
                                  Text(
                                    '正在播放',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _volumeControl() {
    final max = app.volumeMax.toDouble();
    final v = app.volume.clamp(0, max).toDouble();
    return Row(
      children: [
        Icon(
          app.volume <= 0
              ? Icons.volume_off
              : app.volume < 55
              ? Icons.volume_down
              : Icons.volume_up,
          size: 17,
          color: p.dim,
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: v,
                max: max,
                activeColor: p.accent,
                inactiveColor: p.track,
                onChanged: (nv) {
                  app.setVolume(nv);
                  unawaited(_player.setVolume(nv));
                },
              ),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${v.round()}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11.5, color: p.dim),
          ),
        ),
        IconButton(
          onPressed: _toggleBoost,
          tooltip: app.volumeBoostLevel == 2
              ? '响度提升 Plus（上限 200）'
              : app.volumeBoostLevel == 1
              ? '响度提升（上限 120）'
              : '启用响度提升（上限 120）',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            app.volumeBoostLevel == 2 ? Icons.bolt : Icons.bolt_outlined,
            size: 20,
            color: app.volumeBoostLevel == 2
                ? Colors.orange
                : app.volumeBoost
                ? p.accent
                : p.dim,
          ),
        ),
      ],
    );
  }

  Widget _seekCircle(IconData icon, VoidCallback onTap) {
    return Material(
      color: p.surface2.withValues(alpha: .5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 24, color: p.text.withValues(alpha: .75)),
        ),
      ),
    );
  }

  Widget _utils() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _util(
          Icons.article_outlined,
          '作品详情',
          () => Navigator.of(context).push(buildWorkRoute(app, work)),
        ),
        _util(Icons.equalizer_outlined, '均衡器', () => showEqSheet(context, app)),
        _util(
          Icons.timer_outlined,
          app.sleepEndAt != null ? '定时中' : '定时',
          () => showSleepSheet(context, app),
        ),
      ],
    );
  }

  Widget _util(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 18, color: p.muted),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: p.muted)),
        ],
      ),
    );
  }

  // ---------- 歌词页（仅歌词与歌词控件，无翻译） ----------
  Widget _lyricsPanel({required bool showTopBar}) {
    return Column(
      children: [
        if (showTopBar) _topBar(showControls: true),
        Expanded(
          child: _lyrics.isEmpty
              ? Center(
                  child: Text(
                    '暂无歌词',
                    style: TextStyle(fontSize: 13, color: p.dim),
                  ),
                )
              : LayoutBuilder(
                  builder: (ctx, c) {
                    final h = c.maxHeight;
                    _trackLyricViewport(
                      Size(c.maxWidth, h * 0.6),
                      isWide: false,
                    );
                    return Stack(
                      children: [
                        // 歌词仅在垂直居中的 60% 面积内展示（上下各 20% 留白）
                        Positioned(
                          top: h * 0.2,
                          left: 0,
                          right: 0,
                          height: h * 0.6,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: const [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.14, 0.86, 1.0],
                            ).createShader(bounds),
                            child: _buildLyricScrollView(
                              viewportHeight: h * 0.6,
                              isWide: false,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------- 歌词设置（顶部「更多」按钮） ----------
  void _showLyricSettings() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: StatefulBuilder(
            builder: (ctx, setDlg) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.lyrics_outlined, size: 18, color: p.accent),
                    const SizedBox(width: 8),
                    Text(
                      '歌词设置',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close, size: 18, color: p.dim),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '繁简互转',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _convPill(ctx, setDlg, 'orig', '关闭'),
                    const SizedBox(width: 8),
                    _convPill(ctx, setDlg, 'tw', '简 → 繁'),
                    const SizedBox(width: 8),
                    _convPill(ctx, setDlg, 'zh', '繁 → 简'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '字幕偏移',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_lrcOffsetMs > 0 ? '+' : ''}${(_lrcOffsetMs / 1000).toStringAsFixed(1)} s',
                      style: TextStyle(fontSize: 13, color: p.text),
                    ),
                    const SizedBox(width: 6),
                    if (_lrcOffsetMs != 0)
                      GestureDetector(
                        onTap: () => setDlg(() => _lrcOffsetMs = 0),
                        child: Text(
                          '归零',
                          style: TextStyle(fontSize: 12, color: p.accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _offsetBtn(ctx, setDlg, Icons.remove, -100),
                    Expanded(
                      child: Slider(
                        value: _lrcOffsetMs.toDouble().clamp(-10000, 10000),
                        min: -10000,
                        max: 10000,
                        divisions: 200,
                        activeColor: p.accent,
                        inactiveColor: p.track,
                        onChanged: (v) => setDlg(
                          () => _lrcOffsetMs = (v / 100).round() * 100,
                        ),
                      ),
                    ),
                    _offsetBtn(ctx, setDlg, Icons.add, 100),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: p.surface2.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    children: [
                      _lyricSettingTile(
                        icon: Icons.cloud_download_outlined,
                        title: '选择在线歌词',
                        sub: _lyricSourceName ?? '自动匹配',
                        onTap: () => _pickOnlineLyric(ctx),
                      ),
                      Divider(height: 1, indent: 52, color: p.line),
                      _lyricSettingTile(
                        icon: Icons.folder_open_outlined,
                        title: '选择离线歌词',
                        sub: _lyricSourceName != null ? '本地文件' : '从本地选择歌词或字幕文件',
                        onTap: _pickOfflineLyric,
                      ),
                      Divider(height: 1, indent: 52, color: p.line),
                      _libraryAutoTile(setDlg),
                      if (app.lyricsLibraryAuto) ...[
                        Divider(height: 1, indent: 52, color: p.line),
                        _lyricSettingTile(
                          icon: Icons.library_music_outlined,
                          title: '选择歌词库歌词',
                          sub: app.playWork == null
                              ? '歌词库中没有该作品'
                              : '仅显示当前作品的歌词文件',
                          onTap: app.playWork == null
                              ? null
                              : () => _pickLibraryLyric(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _convPill(
    BuildContext ctx,
    StateSetter setDlg,
    String value,
    String label,
  ) {
    final selected = app.conv == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setDlg(() {});
          app.setConv(value);
        },
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.accent.withValues(alpha: .12) : p.surface2,
            border: Border.all(color: selected ? p.accent : p.line),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? p.accent : p.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _offsetBtn(
    BuildContext ctx,
    StateSetter setDlg,
    IconData icon,
    int delta,
  ) {
    return GestureDetector(
      onTap: () => setDlg(() {
        _lrcOffsetMs = (_lrcOffsetMs + delta).clamp(-10000, 10000);
      }),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface2,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 17, color: p.muted),
      ),
    );
  }

  Widget _lyricSettingTile({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        child: Row(
          children: [
            _lyricSettingIcon(icon),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, color: p.text)),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.dim),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: p.dim),
          ],
        ),
      ),
    );
  }

  Widget _libraryAutoTile(StateSetter setDlg) {
    return InkWell(
      onTap: () {
        final next = !app.lyricsLibraryAuto;
        app.setLyricsLibraryAuto(next);
        setDlg(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        child: Row(
          children: [
            _lyricSettingIcon(Icons.library_music_outlined),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '从歌词库自动匹配歌词',
                    style: TextStyle(fontSize: 13.5, color: p.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '优先匹配本地歌词，找不到时使用在线歌词',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.dim),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: app.lyricsLibraryAuto,
              onChanged: (value) {
                app.setLyricsLibraryAuto(value);
                setDlg(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _lyricSettingIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: p.accent),
    );
  }

  Future<void> _pickOnlineLyric(BuildContext rootCtx) async {
    List<LyricCandidate> cands;
    try {
      cands = await ApiService.lyricCandidates(
        app,
        work,
        trackTitle: app.queue.isEmpty ? null : track.title,
        trackPath: app.queue.isEmpty ? null : track.path,
      );
    } catch (_) {
      cands = const [];
    }
    if (!mounted || !rootCtx.mounted) return;
    if (cands.isEmpty) {
      _toast('未找到在线歌词');
      return;
    }
    showDialog(
      context: rootCtx,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 18,
                      color: p.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '选择在线歌词',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close, size: 18, color: p.dim),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.line),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    _onlineLyricItem(
                      ctx,
                      title: '自动匹配',
                      sub: '按曲目名与中文优先自动选择',
                      selected: _lyricSourceName == null,
                      onTap: () async {
                        await _loadOnlineLyric(ctx, null);
                      },
                    ),
                    ...cands.map(
                      (c) => _onlineLyricItem(
                        ctx,
                        title: c.title,
                        sub: c.path,
                        selected: _lyricSourceName == c.title,
                        onTap: () async {
                          await _loadOnlineLyric(ctx, c);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onlineLyricItem(
    BuildContext ctx, {
    required String title,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: selected ? p.accent : p.text,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.dim),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, size: 16, color: p.accent),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOnlineLyric(BuildContext ctx, LyricCandidate? pick) async {
    // 覆盖正在进行的自动匹配，避免它稍后把手动选择的歌词替换回来。
    final seq = ++_lyricSeq;
    List<LyricLine> l;
    try {
      l = await ApiService.fetchLrc(
        app,
        work,
        trackTitle: app.queue.isEmpty ? null : track.title,
        trackPath: app.queue.isEmpty ? null : track.path,
        trackUrl: app.queue.isEmpty ? null : track.url,
        pick: pick,
      );
    } catch (_) {
      l = const [];
    }
    if (!mounted || seq != _lyricSeq) return;
    if (l.isEmpty) {
      _toast('该歌词无法解析');
      return;
    }
    setState(() {
      _lyrics
        ..clear()
        ..addAll(l);
      _lyricKeys.clear();
      _lyricSourceName = pick?.title;
      _lastAutoIdx = -1;
    });
    LyricsHub.instance.setManualLyrics(_lyrics, app.conv);
    if (ctx.mounted) Navigator.pop(ctx);
    _maybeAutoScrollLyric();
  }

  Future<void> _pickOfflineLyric() async {
    final res = await FilePicker.pickFiles(
      dialogTitle: '选择歌词文件',
      type: FileType.custom,
      allowedExtensions: ['lrc', 'txt', 'vtt', 'srt', 'ass', 'ssa'],
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final path = f.path;
    if (path == null) return;
    // 覆盖正在进行的自动匹配，避免它稍后把手动选择的歌词替换回来。
    final seq = ++_lyricSeq;
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = apiDecodeText(bytes: bytes, encoding: '');
      final l = ApiService.parseLyrics(decoded.text);
      if (!mounted || seq != _lyricSeq) return;
      if (l.isEmpty) {
        _toast('文件中没有带时间轴的歌词');
        return;
      }
      setState(() {
        _lyrics
          ..clear()
          ..addAll(l);
        _lyricKeys.clear();
        _lyricSourceName = f.name;
        _lastAutoIdx = -1;
      });
      LyricsHub.instance.setManualLyrics(_lyrics, app.conv);
      _maybeAutoScrollLyric();
    } catch (e) {
      _toast('读取歌词失败：$e');
    }
  }

  Future<void> _pickLibraryLyric() async {
    final currentTrack = app.queue.isEmpty ? null : track;
    final files = await LyricsLibraryService.instance.matchingFiles(
      workId: work.rj,
      trackTitle: currentTrack?.title,
      trackPath: currentTrack?.path,
    );
    if (!mounted) return;
    if (files.isEmpty) {
      _toast('歌词库中没有该作品的歌词');
      return;
    }
    final selected = await showModalBottomSheet<LyricsLibraryFile>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: files.length,
          itemBuilder: (_, i) => ListTile(
            leading: Icon(
              i == 0 ? Icons.star : Icons.lyrics_outlined,
              color: i == 0 ? p.accent : null,
            ),
            title: Text(files[i].name),
            subtitle: Text(files[i].relativePath),
            onTap: () => Navigator.pop(ctx, files[i]),
          ),
        ),
      ),
    );
    if (selected == null) return;
    final l = await LyricsLibraryService.instance.loadFile(selected);
    if (l.isEmpty || !mounted) {
      _toast('该歌词无法解析');
      return;
    }
    ++_lyricSeq;
    setState(() {
      _lyrics
        ..clear()
        ..addAll(l);
      _lyricKeys.clear();
      _lyricSourceName = selected.relativePath;
      _lastAutoIdx = -1;
    });
    LyricsHub.instance.setManualLyrics(_lyrics, app.conv);
    _maybeAutoScrollLyric();
  }

  int _currentLyricIdx() {
    return _lyricIdxAt(_pos);
  }

  int _lyricIdxAt(int positionSeconds) {
    final positionMs = positionSeconds * 1000;
    for (var i = 0; i < _lyrics.length; i++) {
      final t = _lyrics[i].t * 1000 + _lrcOffsetMs;
      final next = i == _lyrics.length - 1
          ? null
          : _lyrics[i + 1].t * 1000 + _lrcOffsetMs;
      if (positionMs >= t && (next == null || positionMs < next)) {
        return i;
      }
    }
    return 0;
  }

  /// 播放位置变化时：若处于自动跟随状态，把当前行滚到中间。
  void _maybeAutoScrollLyric() {
    _requestLyricAlignment();
  }

  void _requestLyricAlignment({bool animated = true, bool force = false}) {
    if (!_lyricAutoFollow || _lyrics.isEmpty) return;
    final idx = _currentLyricIdx();
    if (!force && idx == _lastAutoIdx) return;
    _lastAutoIdx = idx;
    final token = ++_lyricScrollToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignLyricToRenderedLine(idx, token, animated: animated);
    });
  }

  void _alignLyricToRenderedLine(
    int idx,
    int token, {
    required bool animated,
    int attempt = 0,
  }) {
    if (!mounted ||
        token != _lyricScrollToken ||
        !_lyricAutoFollow ||
        idx < 0 ||
        idx >= _lyrics.length) {
      return;
    }
    if (!_lyricScroll.hasClients) {
      _retryLyricAlignment(idx, token, animated, attempt);
      return;
    }

    final target = _renderedLyricTarget(idx);
    if (target == null) {
      _retryLyricAlignment(idx, token, animated, attempt);
      return;
    }
    if (animated) {
      unawaited(_animateLyricTo(target));
    } else {
      _lyricScroll.jumpTo(target);
    }
  }

  void _transitionToRenderedLyric(int idx) {
    if (!_lyricAutoFollow || idx < 0 || idx >= _lyrics.length) return;
    final target = _renderedLyricTarget(idx);
    if (target == null) return;
    ++_lyricScrollToken;
    _lastAutoIdx = idx;
    unawaited(_animateLyricTo(target));
  }

  double? _renderedLyricTarget(int idx) {
    if (!_lyricScroll.hasClients || idx < 0 || idx >= _lyrics.length) {
      return null;
    }
    final renderObject = _lyricKeys[idx]?.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    // 所有歌词行都已参与布局，因此目标位置完全取自真实 RenderObject，
    // 不再使用字体、换行数或累计行高估算。
    final viewport = RenderAbstractViewport.of(renderObject);
    return viewport
        .getOffsetToReveal(renderObject, .5)
        .offset
        .clamp(0.0, _lyricScroll.position.maxScrollExtent)
        .toDouble();
  }

  void _retryLyricAlignment(int idx, int token, bool animated, int attempt) {
    if (attempt >= 6) {
      if (token == _lyricScrollToken) {
        _lastAutoIdx = -1;
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignLyricToRenderedLine(
        idx,
        token,
        animated: animated,
        attempt: attempt + 1,
      );
    });
  }

  Future<void> _animateLyricTo(double target) async {
    try {
      await _lyricScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // 页面切换或用户接管滚动时，当前动画允许被正常取消。
    }
  }

  /// 歌词实际显示文本（繁简互转）
  String _displayLyric(LyricLine l) {
    if (app.conv == 'orig') return l.jp;
    var zh = l.zh;
    if (app.conv == 'tw' || app.conv == 'zh') {
      final mode = app.conv == 'tw' ? 's2t' : 't2s';
      final key = '$mode|$zh';
      var out = _convCache[key];
      if (out == null) {
        try {
          out = apiConvertText(text: zh, mode: mode);
        } catch (_) {
          out = zh;
        }
        _convCache[key] = out;
      }
      return out;
    }
    return zh;
  }

  /// 用户手动滑动歌词列表：暂停自动跟随，3 秒无操作后回到当前行
  void _onLyricUserScroll() {
    // dragDetails 只会来自真实触摸/鼠标拖动；递增 token 立即废弃
    // 正在执行或等待布局的自动定位请求。
    ++_lyricScrollToken;
    _lyricAutoFollow = false;
    _lyricFollowTimer?.cancel();
    _lyricFollowTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _lyricAutoFollow = true;
      _lastAutoIdx = -1;
      _requestLyricAlignment(force: true);
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }
}

class _PlayerPageScrollBehavior extends MaterialScrollBehavior {
  const _PlayerPageScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
