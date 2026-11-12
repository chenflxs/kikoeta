import 'package:flutter/services.dart';

import '../data.dart';

/// 安卓端桌面歌词悬浮窗（原生 WindowManager 覆盖层）
class AndroidLyricsOverlay {
  AndroidLyricsOverlay._();

  static final AndroidLyricsOverlay instance = AndroidLyricsOverlay._();
  static const _ch = MethodChannel('kikoeta/lyrics_overlay');

  bool _available = false;
  String _text = '';
  bool _toggling = false;
  void Function(bool locked)? onLockChanged;

  bool get available => _available;
  String get text => _text;

  Future<void> init() async {
    try {
      _available = await _ch.invokeMethod('isAvailable') == true;
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'lockChanged') {
          final a = call.arguments as Map;
          onLockChanged?.call(a['locked'] == true);
        }
      });
    } catch (_) {
      _available = false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      _available = await _ch.invokeMethod('isAvailable') == true;
      if (_available) return true;
      await _ch.invokeMethod('requestPermission'); // 未授权时拉起系统授权页
      // 轮询等待授权结果（用户从系统授权页返回后生效，最多约 6 秒）
      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 600));
        _available = await _ch.invokeMethod('isAvailable') == true;
        if (_available) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> handleMediaCommand(AppState app, String action) async {
    if (action == 'lyricsLock') {
      app.setLyricsLockedAndroid(!app.lyricsLockedAndroid);
    } else if (action == 'lyricsToggle' && !_toggling) {
      _toggling = true;
      try {
        final enabled = !app.desktopLyricsOn;
        if (enabled && !await requestPermission()) return;
        app.setDesktopLyricsOn(enabled);
      } finally {
        _toggling = false;
      }
    }
  }

  Future<void> show({
    required String text,
    required double fontSize,
    required int color,
    required int outlineColor,
    required double outlineWidth,
    required bool locked,
    int opacityPercent = 100,
    bool followSystemFont = false,
  }) async {
    _text = text;
    if (!_available) return;
    try {
      await _ch.invokeMethod('show', {
        'text': text,
        'fontSize': fontSize,
        'color': color,
        'outlineColor': outlineColor,
        'outlineWidth': outlineWidth,
        'opacityPercent': opacityPercent,
        'followSystemFont': followSystemFont,
        'locked': locked,
      });
    } catch (_) {}
  }

  Future<void> update(String text) async {
    _text = text;
    if (!_available) return;
    try {
      await _ch.invokeMethod('update', {'text': text});
    } catch (_) {}
  }

  Future<void> setLocked(bool locked) async {
    if (!_available) return;
    try {
      await _ch.invokeMethod('setLocked', {'locked': locked});
    } catch (_) {}
  }

  Future<void> setStyle(
    double fontSize,
    int color,
    int outlineColor,
    double outlineWidth,
  ) async {
    if (!_available) return;
    try {
      await _ch.invokeMethod('setStyle', {
        'fontSize': fontSize,
        'color': color,
        'outlineColor': outlineColor,
        'outlineWidth': outlineWidth,
      });
    } catch (_) {}
  }

  Future<void> hide() async {
    if (!_available) return;
    try {
      await _ch.invokeMethod('hide');
    } catch (_) {}
  }
}
