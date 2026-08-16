import 'package:flutter/services.dart';

/// 安卓电池优化白名单（后台播放不被省电策略中断）
class AndroidBattery {
  AndroidBattery._();

  static final AndroidBattery instance = AndroidBattery._();
  static const _ch = MethodChannel('kikoeta/battery_optimization');

  /// 是否已加入电池优化白名单；非安卓/未初始化返回 null
  Future<bool?> isIgnoring() async {
    try {
      return await _ch.invokeMethod('isIgnoringBatteryOptimizations') == true;
    } catch (_) {
      return null;
    }
  }

  /// 请求关闭省电优化（拉起系统授权页），返回请求后的白名单状态
  Future<bool?> requestIgnore() async {
    try {
      return await _ch.invokeMethod('requestIgnoreBatteryOptimizations') ==
          true;
    } catch (_) {
      return null;
    }
  }
}
