import 'dart:io';
import 'dart:convert';

import '../src/rust/api/simple.dart';
import '../src/rust/frb_generated.dart';
import 'app_paths.dart';

/// Rust 侧 SQLite 设置存储的 Dart 桥接
class SettingsStore {
  static bool _ready = false;
  static const _importJournal = 'portable_import_journal';

  static Future<void> init() async {
    if (_ready) return;
    await RustLib.init();
    // Windows：便携 data/ 目录（exe 旁），不污染 AppData/Temp；
    // 其他平台：系统应用支持目录
    final dir = await AppPaths.dataDir();
    final dbPath = '$dir${Platform.pathSeparator}kikoeta.db';
    openSettings(path: dbPath);
    recoverPendingImport();
    _ready = true;
  }

  static void recoverPendingImport() {
    // Roll forward an interrupted import before any consumers load settings.
    final journal = get(_importJournal);
    if (journal != null && journal.isNotEmpty) {
      final values = (jsonDecode(journal) as Map).cast<String, String>();
      for (final entry in values.entries) {
        setSetting(key: entry.key, value: entry.value);
      }
      setSetting(key: _importJournal, value: '');
    }
  }

  static String? get(String key) => getSetting(key: key);

  static void set(String key, String value) {
    setSetting(key: key, value: value);
  }

  static void importPortable(Map<String, String> values) {
    setSetting(key: _importJournal, value: jsonEncode(values));
    for (final entry in values.entries) {
      setSetting(key: entry.key, value: entry.value);
    }
    setSetting(key: _importJournal, value: '');
  }

  /// 清空全部设置（含 token）——「完全重置」用
  static void clearAll() {
    clearAllSettings();
  }
}
