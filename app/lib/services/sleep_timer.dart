import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data.dart';
import 'player_service.dart';

/// 定时关闭：到点停止播放；桌面端退出进程，移动端仅释放播放状态。
/// 幂等：触发后立即清除 sleepEndAt，重复检查不会二次触发。
class SleepTimer {
  SleepTimer._();

  static bool _fired = false;

  static void check(AppState app) {
    final end = app.sleepEndAt;
    if (end == null) {
      _fired = false;
      return;
    }
    if (!DateTime.now().isAfter(end)) return;
    if (_fired) return;
    _fired = true;

    final wasPlaying = app.playing;
    app.playing = false;
    app.clearSleep();
    if (!wasPlaying) return; // 手册：到点时若未播放则不动作
    AppPlayer.instance.stop();
    app.notify();

    // 桌面端：停止后退出进程（手册 4.6：Windows/Linux/macOS 到点退出）
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      Future.delayed(const Duration(milliseconds: 600), () => exit(0));
    }
  }

  static Timer start(AppState app) =>
      Timer.periodic(const Duration(seconds: 1), (_) => check(app));

  /// 立即触发定时关闭（供「播放完毕」模式在列表播完后调用）
  static void triggerNow(AppState app) {
    if (_fired) return;
    _fired = true;
    final wasPlaying = app.playing;
    app.playing = false;
    app.clearSleep();
    app.disarmPlayEnd();
    if (!wasPlaying) return; // 手册：到点时若未播放则不动作
    AppPlayer.instance.stop();
    app.notify();

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      Future.delayed(const Duration(milliseconds: 600), () => exit(0));
    }
  }
}
