import 'dart:collection';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError, debugPrint;
import 'package:flutter/services.dart' show PlatformException;

/// Session diagnostics and the exported UTF-8 snapshot.
class AppLog {
  AppLog._();

  static const settingKey = 'app_logging_enabled';
  static const maxBytes = 1024 * 1024;
  static const _detailLimit = 8192;
  static final _urls = RegExp(
    r'''(?:https?|socks[45]h?|ftp)://[^\s<>"']+''',
    caseSensitive: false,
  );
  static final _headers = RegExp(
    r'^[ \t]*(?:authorization|proxy-authorization|cookie|set-cookie)[ \t]*:[^\r\n]*',
    caseSensitive: false,
    multiLine: true,
  );
  static final _secrets = RegExp(
    r'''(\b(?:password|passwd|api[_-]?key|(?:access[_-]?|refresh[_-]?)?token)["']?[ \t]*[:=][ \t]*|\bBearer[ \t]+)(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s,;}\]]+)''',
    caseSensitive: false,
  );
  static Uint8List _header = _buildHeader('unknown');
  static final _entries = Queue<Uint8List>();
  static int _length = 0;
  static bool _enabled = false;

  static bool get enabled => _enabled;

  static void installFlutterHooks() {
    final consolePrint = debugPrint;
    var reportingFlutterError = false;
    debugPrint = (message, {wrapWidth}) {
      if (_enabled && !reportingFlutterError && message != null) {
        _append('DEBUG', 'flutter debugPrint', _detail(message));
      }
      consolePrint(message, wrapWidth: wrapWidth);
    };

    final flutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      recordError('flutter framework', details.exception, details.stack);
      reportingFlutterError = true;
      try {
        flutterOnError?.call(details);
      } finally {
        reportingFlutterError = false;
      }
    };
    final dispatcher = PlatformDispatcher.instance;
    final platformOnError = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      recordError('dart unhandled', error, stack);
      return platformOnError?.call(error, stack) ?? false;
    };
  }

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

  static void record(String event) {
    if (!_enabled) return;
    _append('INFO', event);
  }

  static void recordError(String event, Object error, [StackTrace? stack]) {
    if (!_enabled) return;
    var detail = '';
    try {
      final message = switch (error) {
        FormatException(:final message) => message,
        PlatformException(:final code, :final message) =>
          '$code: ${message ?? ''}',
        _ => error.toString(),
      };
      detail = _detail(message);
      if (stack != null) detail += _detail(stack.toString());
      if (error is PlatformException && error.stacktrace != null) {
        detail += '\n  Native stack:${_detail(error.stacktrace!)}';
      }
    } catch (_) {
      // A broken exception formatter must not interfere with its caller.
    }
    _append('ERROR', '$event error=${error.runtimeType}', detail);
  }

  static String _detail(String text) {
    final truncated = text.length > _detailLimit;
    final prefix = truncated ? text.substring(0, _detailLimit) : text;
    final redacted = prefix
        .replaceAll(_urls, '[url]')
        .replaceAll(_headers, '[header redacted]')
        .replaceAllMapped(_secrets, (match) => '${match[1]}[redacted]')
        .trimRight();
    if (redacted.isEmpty) return '';
    return '\n  ${redacted.replaceAll(RegExp(r'\r\n?|\n'), '\n  ')}'
        '${truncated ? '\n  [truncated]' : ''}';
  }

  static void _append(String level, String event, [String detail = '']) {
    final entry = utf8.encode(
      '${DateTime.now().toUtc().toIso8601String()} $level $event$detail\n',
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
