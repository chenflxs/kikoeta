import 'package:flutter/services.dart';

/// Jetpack Media3 媒体会话桥接（安卓）：
/// Dart 上报播放状态 → 原生 MediaSession（通知/锁屏卡片）；
/// 原生控制命令 → 回调 Dart 执行（mpv 播放）。
class AndroidMedia3 {
  AndroidMedia3._();

  static const _ch = MethodChannel('kikoeta/media3');

  /// MediaSession 控制命令回调：action = play/pause/stop/seekTo/next/previous
  static void Function(String action, int positionMs)? onCommand;

  static Future<void> init() async {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'command') {
        final a = call.arguments as Map;
        onCommand?.call(
          a['action'] as String? ?? '',
          (a['positionMs'] as num?)?.toInt() ?? 0,
        );
      }
      return null;
    });
  }

  /// 启动媒体会话前台服务（应用启动时调用一次）
  static Future<void> ensureSession() async {
    try {
      await _ch.invokeMethod('ensureSession');
    } catch (_) {}
  }

  /// 上报播放状态（刷新通知/锁屏卡片）
  static Future<void> updateState({
    required bool isPlaying,
    required int positionMs,
    required int durationMs,
    required String title,
    required String artist,
    String? artworkUrl,
    required String mediaId,
    bool hideCard = false,
    bool logoCover = false,
  }) async {
    // ignore: avoid_print
    print(
      '[media3] updateState playing=$isPlaying pos=$positionMs title=$title',
    );
    try {
      await _ch.invokeMethod('updateState', {
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'title': title,
        'artist': artist,
        'artworkUrl': artworkUrl,
        'mediaId': mediaId,
        'hideCard': hideCard,
        'logoCover': logoCover,
      });
    } catch (e) {
      // ignore: avoid_print
      print('[media3] updateState FAILED: $e');
    }
  }

  /// 清空会话（停止播放/无曲目时）
  static Future<void> clearSession() async {
    try {
      await _ch.invokeMethod('clearSession');
    } catch (_) {}
  }
}
