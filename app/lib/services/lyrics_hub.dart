import 'dart:io';

import '../data.dart';
import '../src/rust/api/textconv.dart';
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

  void start() {
    if (_started) return;
    _started = true;
    AppPlayer.instance.position.listen((_) => _tick());
  }

  void setLyrics(List<LyricLine> lyrics, String conv) {
    _lyrics = List.of(lyrics);
    _conv = conv;
    _convCache.clear();
    _lastSent = '';
    _tick();
  }

  void setConv(String conv) {
    if (_conv == conv) return;
    _conv = conv;
    _convCache.clear();
    _tick();
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

  void _tick() {
    final line = currentLine;
    if (line.isEmpty) return;
    if (line == _lastSent) return;
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
