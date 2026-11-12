import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Session diagnostics. Callers supply event names and safe metadata only.
class AppLog {
  AppLog._();

  static const settingKey = 'app_logging_enabled';
  static const maxBytes = 1024 * 1024;
  static final _entries = Queue<Uint8List>();
  static int _length = 0;
  static bool _enabled = false;

  static bool get enabled => _enabled;

  static void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (value) record('logging enabled');
  }

  static void record(String event, {Object? error, int? elapsedMs}) {
    if (!_enabled) return;
    final entry = utf8.encode(
      '${DateTime.now().toUtc().toIso8601String()} $event'
      '${error == null ? '' : ' error=${error.runtimeType}'}'
      '${elapsedMs == null ? '' : ' elapsed_ms=$elapsedMs'}\n',
    );
    if (entry.length > maxBytes) return;
    while (_length + entry.length > maxBytes) {
      _length -= _entries.removeFirst().length;
    }
    _entries.addLast(entry);
    _length += entry.length;
  }

  static Future<T> track<T>(String event, Future<T> Function() action) =>
      _enabled ? _track(event, action) : action();

  static Future<T> _track<T>(String event, Future<T> Function() action) async {
    final timer = Stopwatch()..start();
    try {
      final result = await action();
      record('$event ok', elapsedMs: timer.elapsedMilliseconds);
      return result;
    } catch (error) {
      record(
        '$event failed',
        error: error,
        elapsedMs: timer.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  static Uint8List snapshot() {
    final bytes = Uint8List(_length);
    var offset = 0;
    for (final entry in _entries) {
      bytes.setAll(offset, entry);
      offset += entry.length;
    }
    return bytes;
  }

  static void clear() {
    _entries.clear();
    _length = 0;
  }
}
