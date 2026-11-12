import 'dart:io';

import 'app_log.dart';

/// Small, payload-free startup trace: available even before Rust is initialized.
class StartupTrace {
  static final _clock = Stopwatch()..start();
  static RandomAccessFile? _file;
  static bool _ready = false;
  static bool _rasterized = false;

  static void initialize() {
    if (!Platform.isWindows) return;
    try {
      final directory = Directory(
        '${File(Platform.resolvedExecutable).parent.path}/kikoeta_data',
      )..createSync(recursive: true);
      final file = File('${directory.path}/startup.log');
      if (file.existsSync()) {
        file.copySync('${directory.path}/startup.previous.log');
      }
      _file = file.openSync(mode: FileMode.write);
      _file!.writeStringSync('pid=$pid\n');
    } catch (_) {
      _file = null;
    }
  }

  static void mark(String event) {
    AppLog.record('startup $event');
    try {
      _file?.writeStringSync('${_clock.elapsedMilliseconds}ms $event\n');
      if (event == 'startup-ready') _ready = true;
      if (event == 'first-rasterized') _rasterized = true;
      if (_ready && _rasterized) {
        _file?.closeSync();
        _file = null;
      }
    } catch (_) {
      // Diagnostics must not prevent startup in a read-only installation.
    }
  }

  static Future<T> stage<T>(String name, Future<T> Function() action) async {
    mark('$name begin');
    try {
      final result = await action();
      mark('$name ready');
      return result;
    } catch (error) {
      mark('$name failed: ${error.runtimeType}');
      rethrow;
    }
  }
}
