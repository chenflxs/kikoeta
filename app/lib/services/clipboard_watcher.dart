import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';

/// 剪贴板 RJ 自动检测：检测到新的 RJ 号时提示一键搜索
class ClipboardWatcher {
  ClipboardWatcher._();

  static String? _lastRj;
  static String _lastRaw = '';
  static Timer? _dismissTimer;
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _activeSnackBar;

  static Timer start(
    AppState app,
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) {
    return Timer.periodic(const Duration(seconds: 3), (_) {
      _check(app, messengerKey);
    });
  }

  static Future<void> _check(
    AppState app,
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) async {
    if (!app.clipboardDetect) return;
    String text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text ?? '';
    } catch (_) {
      return;
    }
    if (text == _lastRaw) return;
    _lastRaw = text;
    final rj = _extractRj(text);
    if (rj == null || rj == _lastRj) return;
    _lastRj = rj;
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    _dismissTimer?.cancel();
    messenger.clearSnackBars();
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    controller;
    controller = messenger.showSnackBar(
      SnackBar(
        content: Text('检测到 $rj，点击搜索'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '搜索',
          onPressed: () {
            _dismissTimer?.cancel();
            if (identical(_activeSnackBar, controller)) {
              _activeSnackBar = null;
              controller.close();
            }
            app.requestSearch(rj);
          },
        ),
      ),
    );
    _activeSnackBar = controller;
    controller.closed.whenComplete(() {
      if (!identical(_activeSnackBar, controller)) return;
      _activeSnackBar = null;
      _dismissTimer?.cancel();
      _dismissTimer = null;
    });
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (!identical(_activeSnackBar, controller)) return;
      _activeSnackBar = null;
      _dismissTimer = null;
      controller.close();
    });
  }

  static String? _extractRj(String text) {
    final m = RegExp(r'RJ\d{4,8}', caseSensitive: false).firstMatch(text);
    if (m == null) return null;
    return m.group(0)!.toUpperCase();
  }
}
