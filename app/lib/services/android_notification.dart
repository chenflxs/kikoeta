import 'package:flutter/services.dart';

/// 安卓通知权限（Android 13+ 媒体通知/锁屏卡片）
class AndroidNotification {
  AndroidNotification._();

  static const _ch = MethodChannel('kikoeta/notification');

  /// 是否已授予通知权限（Android 13 以下恒为 true）
  static Future<bool> hasPermission() async {
    try {
      return await _ch.invokeMethod('hasPermission') == true;
    } catch (_) {
      return true;
    }
  }

  /// 请求通知权限（首次会弹系统授权框）
  static Future<void> requestPermission() async {
    try {
      await _ch.invokeMethod('requestPermission');
    } catch (_) {}
  }
}
