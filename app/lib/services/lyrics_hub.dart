import 'dart:async';
import 'dart:io';

import '../data.dart';
import '../src/rust/api/textconv.dart';
import 'api_service.dart';
import 'android_lyrics_overlay.dart';
import 'desktop_lyrics_overlay.dart';
import 'player_service.dart';

/// 桌面歌词全局中枢：
/// 持有当前曲目的歌词列表，全局监听播放位置，即使播放器页关闭也会持续刷新悬浮窗。
class LyricsHub {
  LyricsHub._();

  static final LyricsHub instance = LyricsHub._();

  List<LyricLine> _lyrics = [];
  String _conv = 'orig';
  final Map<String, String> _convCache = {};
  bool _started = false;
  String _lastSent = '';
  AppState? _app;
  String? _trackKey;
  String? _manualTrackKey;
  int _matchSeq = 0;

  void start() {
    if (_started) return;
    _started = true;
    AppPlayer.instance.position.listen((_) => _tick());
    AppPlayer.instance.released.listen((_) => setLyrics(const [], _conv));
  }

  /// 绑定全局播放状态，使自动歌词匹配不依赖播放器页是否仍在路由栈中。
  void bind(AppState app) {
    if (identical(_app, app)) return;
    _app?.removeListener(_onAppChanged);
    _app = app;
    app.addListener(_onAppChanged);
    _onAppChanged();
  }

  void setLyrics(List<LyricLine> lyrics, String conv) {
    _lyrics = List.of(lyrics);
    _conv = conv;
    _convCache.clear();
    _lastSent = '';
    // 新曲目没有歌词时也必须发送空文本，桌面悬浮窗才能清除上一句。
    _tick(force: true);
  }

  /// 手动选词只覆盖当前曲目的自动匹配结果，切歌后自动恢复匹配。
  void setManualLyrics(List<LyricLine> lyrics, String conv) {
    _manualTrackKey = _trackKey;
    setLyrics(lyrics, conv);
  }

  void setConv(String conv) {
    if (_conv == conv) return;
    _conv = conv;
    _convCache.clear();
    _tick();
  }

  void _onAppChanged() {
    final app = _app;
    if (app == null) return;
    final key = _currentTrackKey(app);
    if (key == _trackKey) return;
    unawaited(_matchCurrentTrack(app, key));
  }

  String? _currentTrackKey(AppState app) {
    final work = app.playWork;
    if (work == null || app.queue.isEmpty) return null;
    final index = app.trackIdx.clamp(0, app.queue.length - 1).toInt();
    final track = app.queue[index];
    return '${work.rj}|${track.path}|${track.url ?? ''}';
  }

  Future<void> _matchCurrentTrack(AppState app, String? key) async {
    _trackKey = key;
    _manualTrackKey = null;
    final seq = ++_matchSeq;
    setLyrics(const [], app.conv);
    if (key == null) return;

    final work = app.playWork;
    if (work == null || app.queue.isEmpty) return;
    final index = app.trackIdx.clamp(0, app.queue.length - 1).toInt();
    final track = app.queue[index];
    try {
      final lyrics = await ApiService.fetchLrc(
        app,
        work,
        trackTitle: track.title,
        trackPath: track.path,
        trackUrl: track.url,
      );
      if (seq != _matchSeq || key != _trackKey || _manualTrackKey == key) {
        return;
      }
      setLyrics(lyrics, app.conv);
    } catch (_) {
      // 清空已在请求开始时完成；失败时不能留下上一首歌词。
    }
  }

  /// 当前应显示的歌词行
  String get currentLine {
    if (_lyrics.isEmpty) return '';
    final pos = AppPlayer.instance.player.state.position.inSeconds;
    var idx = 0;
    for (var i = 0; i < _lyrics.length; i++) {
      if (pos >= _lyrics[i].t) {
        idx = i;
      } else {
        break;
      }
    }
    return _display(_lyrics[idx]);
  }

  void _tick({bool force = false}) {
    final line = currentLine;
    if (!force && line == _lastSent) return;
    _lastSent = line;
    if (Platform.isWindows && DesktopLyricsOverlay.instance.isVisible) {
      DesktopLyricsOverlay.instance.update(line);
    } else if (Platform.isAndroid) {
      AndroidLyricsOverlay.instance.update(line);
    }
  }

  String _display(LyricLine l) {
    if (_conv == 'orig') return l.jp;
    var zh = l.zh;
    if (_conv == 'tw' || _conv == 'zh') {
      final mode = _conv == 'tw' ? 's2t' : 't2s';
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
}
