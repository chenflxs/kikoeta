import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 应用数据目录解析（便携优先）：
/// - Windows：可执行文件旁的 `kikoeta_data/` 目录（绿色/便携布局），
///   不污染 AppData/Temp；注意不能叫 `data/`——那是 Flutter Windows
///   应用包自带的 bundle 目录（flutter_assets / icudtl.dat 所在）。
///   若该目录不可写（如装在 Program Files）则回退到系统应用支持目录。
/// - 其他平台（Android / iOS / macOS / Linux）：系统应用支持目录。
class AppPaths {
  static String? _cached;

  /// 解析并确保应用数据目录存在（幂等，进程内只探测一次）
  static Future<String> dataDir() async {
    if (_cached != null) return _cached!;
    String dir;
    if (Platform.isWindows) {
      dir = await _portableDir();
    } else {
      dir = (await getApplicationSupportDirectory()).path;
      await Directory(dir).create(recursive: true);
    }
    _cached = dir;
    return dir;
  }

  /// Persistent downloaded files live beside the app, in the root `voice`
  /// directory. Non-file work metadata stays in the database.
  static Future<String> voiceDir() async {
    final root = Platform.isWindows
        ? File(Platform.resolvedExecutable).parent.path
        : await dataDir();
    final dir = '$root${Platform.pathSeparator}voice';
    await Directory(dir).create(recursive: true);
    return dir;
  }

  /// Windows 便携目录：`<exe 所在目录>/kikoeta_data`
  static Future<String> _portableDir() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final portable = '$exeDir${Platform.pathSeparator}kikoeta_data';
    final probe = File('$portable${Platform.pathSeparator}.w');
    try {
      await Directory(portable).create(recursive: true);
      await probe.writeAsString('', flush: true);
      await probe.delete();
      return portable;
    } catch (_) {
      // 便携目录不可写 → 回退到系统应用支持目录（保证应用可用）
      final d = (await getApplicationSupportDirectory()).path;
      await Directory(d).create(recursive: true);
      return d;
    }
  }
}
