import 'dart:collection';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

/// Session diagnostics. Callers supply event names and safe metadata only.
class AppLog {
  AppLog._();

  static const settingKey = 'app_logging_enabled';
  static const maxBytes = 1024 * 1024;
  static Uint8List _header = _buildHeader('unknown');
  static final _entries = Queue<Uint8List>();
  static int _length = 0;
  static bool _enabled = false;

  static bool get enabled => _enabled;

  static void setAppVersion(String version) {
    _header = _buildHeader(version);
    _discardOldEntries(maxBytes - _header.length);
  }

  static Uint8List _buildHeader(String appVersion) {
    String osVersion;
    try {
      osVersion = Platform.operatingSystemVersion;
    } on OSError {
      osVersion = 'unknown';
    }
    return utf8.encode(
      'Kikoeta diagnostic log\n'
      'app_version=${_headerValue(appVersion)}\n'
      'os=${Platform.operatingSystem}\n'
      'os_version=${_headerValue(osVersion)}\n'
      'runtime_abi=${Abi.current()}\n\n',
    );
  }

  static String _headerValue(String value) {
    final line = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty) return 'unknown';
    return line.length <= 256 ? line : line.substring(0, 256);
  }

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
    final available = maxBytes - _header.length - entry.length;
    if (available < 0) return;
    _discardOldEntries(available);
    _entries.addLast(entry);
    _length += entry.length;
  }

  static void _discardOldEntries(int limit) {
    while (_length > limit) {
      _length -= _entries.removeFirst().length;
    }
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
    final bytes = Uint8List(_header.length + _length)..setAll(0, _header);
    var offset = _header.length;
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
