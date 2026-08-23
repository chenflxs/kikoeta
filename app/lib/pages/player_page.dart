import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart' hide Track;

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../services/android_lyrics_overlay.dart';
import '../services/lyrics_hub.dart';
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

class _PlayerPageState extends State<PlayerPage> {
  final PageController _pageCtrl = PageController();
  final List<LyricLine> _lyrics = [];
  final List<StreamSubscription> _subs = [];
  Timer? _sleepTimer;
  int _pos = 0;
  int _dur = 0;
  int _lyricSeq = 0;
  final ScrollController _lyricScroll = ScrollController();
  Timer? _lyricFollowTimer;
  bool _lyricAutoFollow = true;
  bool _lyricProgrammatic = false;
  int _lyricScrollToken = 0;
  int _lastAutoIdx = -1;
  int _lrcOffsetMs = 0; // 字幕偏移（毫秒，正数表示歌词提前显示）
  String? _lyricSourceName; // 当前歌词来源（在线文件名 / 本地文件名）
  double _lyricPanelWidth = 320;
  bool _switching = false; // 切歌防抖：避免 completed 与手动点击重复触发
  DateTime? _lastAutoNext; // completed 自动跳转去重
  final Map<String, String> _convCache = {};
  late String _lastConv;
  late bool _lastAppPlaying;
  bool _opening = false; // 正在打开媒体
  bool _buffering = false; // 缓冲中
  int _lastSavedPos = 0; // 上次保存播放位置（节流）

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
    _lastConv = app.conv;
    _lastAppPlaying = app.playing;
    _syncPlayerSnapshot();
    app.addListener(_onAppStateChanged);
    _subs.add(
      AppPlayer.instance.position.listen((d) {
        if (mounted) {
          // 值未变化时跳过重建（同一秒内重复 tick 不重绘整页）
          if (d != _pos) setState(() => _pos = d);
          _maybeAutoScrollLyric();
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
            app.resumePosition = _pos;
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
      _openCurrent(autoplay: false).then((_) async {
        if (mounted && AppPlayer.instance.opened && resume > 0) {
          try {
            await _player.seek(Duration(seconds: resume));
          } catch (_) {}
          if (mounted) setState(() => _pos = resume);
        }
      });
    } else if (app.playing && app.queue.isNotEmpty && needsOpen) {
      // 全局播放器可能仍打开着上一部作品；目标媒体不同也必须重新打开。
      _openCurrent();
    }
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final seq = ++_lyricSeq;
    // 切歌后先清掉上一首的歌词；请求失败或新曲目无歌词时也不能保留旧内容。
    if (_lyrics.isNotEmpty) {
      setState(_lyrics.clear);
    }
    LyricsHub.instance.setLyrics(const [], app.conv);
    final currentTrack = app.queue.isEmpty ? null : track;
    try {
      final l = await ApiService.fetchLrc(
        app,
        work,
        trackTitle: currentTrack?.title,
        trackPath: currentTrack?.path,
        trackUrl: currentTrack?.url,
      );
      if (mounted && seq == _lyricSeq && !_sameLyrics(l, _lyrics)) {
        setState(
          () => _lyrics
            ..clear()
            ..addAll(l),
        );
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
    app.removeListener(_onAppStateChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _sleepTimer?.cancel();
    _lyricFollowTimer?.cancel();
    _lyricScroll.dispose();
    _pageCtrl.dispose();
    // 离开播放器页时保存播放位置（重启可恢复）
    if (app.queue.isNotEmpty) {
      app.resumePosition = _pos;
      app.savePlayState();
    }
    super.dispose();
  }

  void _onAppStateChanged() {
    final playingChanged = app.playing != _lastAppPlaying;
    _lastAppPlaying = app.playing;
    var needsRebuild = playingChanged;
    if (app.conv != _lastConv) {
      _lastConv = app.conv;
      _convCache.clear();
      LyricsHub.instance.setConv(app.conv);
      needsRebuild = true;
    }
    if (needsRebuild && mounted) setState(() {});
  }

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
    final url = track.url;
    if (url == null) {
      app.playing = false;
      app.notify();
      _toast('文件流需登录后可用');
      return;
    }
    if (mounted) setState(() => _opening = true);
    try {
      await _openMedia(url, autoplay: autoplay);
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
    app.notify();
    setState(() {});
    _loadLyrics();
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

  void _jumpTo(int idx) {
    if (idx == app.trackIdx) return;
    if (app.queue.isEmpty || _switching) return;
    _switching = true;
    app.trackIdx = idx;
    _pos = 0;
    _dur = 0;
    AppPlayer.instance.opened = false;
    app.notify();
    setState(() {});
    _loadLyrics();
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
    app.notify();
    setState(() {});
    _loadLyrics();
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

  @override
  Widget build(BuildContext context) {
    final w = app.playWork;
    if (w == null || app.queue.isEmpty) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Center(
          child: Text('暂无播放内容', style: TextStyle(fontSize: 14, color: p.dim)),
        ),
      );
    }
    return Scaffold(
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
            child: LayoutBuilder(
              builder: (context, c) {
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
    );
  }

  // ---------- 竖屏：左滑进歌词页，右滑回封面页 ----------
  Widget _portrait() {
    return PageView(
      controller: _pageCtrl,
      children: [
        Column(
          children: [
            _topBar(showControls: false),
            Expanded(child: _coverBody(alignLeft: false)),
          ],
        ),
        _lyricsPanel(showTopBar: true),
      ],
    );
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

  Widget _topBar({bool showControls = true}) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.keyboard_arrow_down, size: 26),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '正在播放',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // 桌面歌词/更多仅出现在歌词页右上（封面页通过左右滑动进入歌词页）
        if (showControls) ...[
          IconButton(
            onPressed: _toggleDesktopLyrics,
            tooltip: '桌面歌词',
            icon: Icon(
              app.desktopLyricsOn ? Icons.lyrics : Icons.lyrics_outlined,
              size: 22,
              color: app.desktopLyricsOn ? p.accent : null,
            ),
          ),
          IconButton(
            onPressed: _showLyricSettings,
            icon: const Icon(Icons.more_horiz, size: 22),
          ),
        ],
      ],
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
            onPressed: () {
              if (app.playing) {
                _player.pause();
                app.playing = false;
              } else {
                if (_opened) {
                  _player.play();
                } else {
                  _openCurrent();
                }
                app.playing = true;
              }
              app.notify();
              setState(() {});
            },
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
                divisions: max.round(),
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
                    _lyricPanelWidth = c.maxWidth;
                    final h = c.maxHeight;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          _lyricAutoFollow &&
                          _lastAutoIdx < 0 &&
                          _lyricScroll.hasClients) {
                        _lastAutoIdx = _currentLyricIdx();
                        _scrollLyricTo(_lastAutoIdx, animated: false);
                      }
                    });
                    return Stack(
                      children: [
                        // 歌词仅在垂直居中的 60% 面积内展示（上下各 20% 留白）
                        Positioned(
                          top: h * 0.2,
                          left: 0,
                          right: 0,
                          height: h * 0.6,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n is UserScrollNotification &&
                                  n.direction != ScrollDirection.idle) {
                                _onLyricUserScroll();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _lyricScroll,
                              // 上下各留半屏空白，保证第一行与最后一行也能居中
                              padding: EdgeInsets.symmetric(
                                vertical: math.max(h * 0.3, 40),
                              ),
                              itemCount: _lyrics.length,
                              itemBuilder: (ctx, i) {
                                final l = _lyrics[i];
                                final current = i == _currentLyricIdx();
                                final main = _displayLyric(l);
                                return InkWell(
                                  onTap: () => _seekTo(l.t),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                      horizontal: 20,
                                    ),
                                    child: Text(
                                      main,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: current ? 16 : 14.5,
                                        fontWeight: current
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                        color: current ? p.text : p.dim,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                _lyricSettingTile(
                  icon: Icons.cloud_download_outlined,
                  title: '选择在线歌词',
                  sub: _lyricSourceName ?? '自动匹配',
                  onTap: () => _pickOnlineLyric(ctx),
                ),
                _lyricSettingTile(
                  icon: Icons.folder_open_outlined,
                  title: '选择离线歌词',
                  sub: _lyricSourceName != null ? '本地文件' : '从本地选择歌词或字幕文件',
                  onTap: _pickOfflineLyric,
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
          app.conv = value;
          app.notify();
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: p.accent),
            const SizedBox(width: 10),
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
      _lyricSourceName = pick?.title;
      _lastAutoIdx = -1;
    });
    LyricsHub.instance.setLyrics(_lyrics, app.conv);
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
        _lyricSourceName = f.name;
        _lastAutoIdx = -1;
      });
      LyricsHub.instance.setLyrics(_lyrics, app.conv);
      _maybeAutoScrollLyric();
    } catch (e) {
      _toast('读取歌词失败：$e');
    }
  }

  int _currentLyricIdx() {
    final positionMs = _pos * 1000;
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

  /// 播放位置变化时：若处于自动跟随状态，把当前行滚到中间
  void _maybeAutoScrollLyric() {
    if (!_lyricAutoFollow || _lyrics.isEmpty || !_lyricScroll.hasClients) {
      return;
    }
    final idx = _currentLyricIdx();
    if (idx != _lastAutoIdx) {
      _lastAutoIdx = idx;
      _scrollLyricTo(idx);
    }
  }

  /// 把第 idx 行滚动到列表中间
  void _scrollLyricTo(int idx, {bool animated = true}) {
    if (!_lyricScroll.hasClients || _lyrics.isEmpty) return;
    final token = ++_lyricScrollToken;
    final width = math.max(_lyricPanelWidth, 100.0);
    var offset = 0.0;
    for (var i = 0; i < idx; i++) {
      offset += _lyricLineHeight(_displayLyric(_lyrics[i]), width, false);
    }
    final h = _lyricLineHeight(_displayLyric(_lyrics[idx]), width, true);
    // 列表上下已各留半屏 padding，首尾行同样可滚动到正中间
    final target = (offset + h / 2)
        .clamp(0.0, _lyricScroll.position.maxScrollExtent)
        .toDouble();
    _lyricProgrammatic = true;
    if (animated) {
      _lyricScroll
          .animateTo(
            target,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (token == _lyricScrollToken) _lyricProgrammatic = false;
          });
    } else {
      _lyricScroll.jumpTo(target);
      _lyricProgrammatic = false;
    }
  }

  /// 估算歌词行高（CJK 字符按 1em、ASCII 按 0.55em 估算换行）
  double _lyricLineHeight(String text, double width, bool current) {
    final fontSize = current ? 16.0 : 14.5;
    final contentWidth = math.max(width - 40, 40.0);
    var cjk = 0, ascii = 0;
    for (final r in text.runes) {
      if (r > 0x2E7F) {
        cjk++;
      } else {
        ascii++;
      }
    }
    final textWidth = cjk * fontSize + ascii * fontSize * 0.55;
    final lines = (textWidth / contentWidth).ceil().clamp(1, 4);
    return lines * fontSize * 1.45 + 14;
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
    if (_lyricProgrammatic) return;
    _lyricAutoFollow = false;
    _lyricFollowTimer?.cancel();
    _lyricFollowTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _lyricAutoFollow = true;
      _lastAutoIdx = -1;
      _scrollLyricTo(_currentLyricIdx());
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: TextStyle(fontSize: 12.5, color: p.text)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
          backgroundColor: p.toast,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}
