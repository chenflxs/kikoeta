import 'package:flutter/services.dart';

/// 安卓音频控制：拔出耳机自动暂停 / 音频焦点
class AndroidAudio {
  AndroidAudio._();

  static const _ch = MethodChannel('kikoeta/audio_control');

  /// 原生侧请求暂停（耳机拔出 / 音频焦点丢失）时的回调
  static void Function()? onPauseRequested;

  static Future<void> init() async {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'pause') {
        onPauseRequested?.call();
      }
      return null;
    });
  }

  /// 拔出耳机自动暂停开关（仅安卓）
  static Future<void> setEarPause(bool enabled) async {
    try {
      await _ch.invokeMethod('setEarPause', {'enabled': enabled});
    } catch (_) {}
  }

  /// 忽略音频焦点开关（仅安卓；开启后不申请焦点，也不因焦点丢失暂停）
  static Future<void> setIgnoreAudioFocus(bool ignore) async {
    try {
      await _ch.invokeMethod('setIgnoreAudioFocus', {'ignore': ignore});
    } catch (_) {}
  }

  /// 实际播放前申请焦点；暂停、停止或播放结束后释放（仅安卓）。
  static Future<void> setPlaybackActive(bool active) async {
    try {
      await _ch.invokeMethod('setPlaybackActive', {'active': active});
    } catch (_) {}
  }
}
