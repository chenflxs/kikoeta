import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../src/rust/api/simple.dart';
import '../src/rust/frb_generated.dart';

/// Rust 侧 SQLite 设置存储的 Dart 桥接
class SettingsStore {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    await RustLib.init();
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final dbPath = '${dir.path}${Platform.pathSeparator}kikoeta.db';
    openSettings(path: dbPath);
    _ready = true;
  }

  static String? get(String key) => getSetting(key: key);

  static void set(String key, String value) => setSetting(key: key, value: value);

  /// 清空全部设置（含 token）——「完全重置」用
  static void clearAll() => clearAllSettings();
}
