import 'dart:async';

import 'package:http/http.dart' as http;
import 'kikoeru_writeback_access.dart';

/// Writes a copy to the original self-hosted site after the local save.
class KikoeruLyricsWriteback {
  KikoeruLyricsWriteback._(this._access);

  static final _mediaRoute = RegExp(r'^(?:download|stream)/([0-9]+)/[0-9]+$');
  final KikoeruWritebackAccess _access;
  Uri get _endpoint => _access.endpoint;
  KikoeruWritebackStatus get status => _access.status;
  Future<bool?>? _supported;
  Future<bool?> check() => _supported ??= _probe();

  static bool isValidKey(String key) =>
      KikoeruWritebackCredentials.isValidKey(key);

  static KikoeruLyricsWriteback? connect(
    String? sourceBase,
    Map<String, String> headers, {
    required String key,
    KikoeruWritebackCredentials Function()? credentials,
  }) {
    final access = KikoeruWritebackAccess.connect(
      sourceBase,
      credentials ??
          () => KikoeruWritebackCredentials(
            authorization: headers['Authorization'],
            key: key,
          ),
    );
    return access == null ? null : KikoeruLyricsWriteback._(access);
  }

  /// null means writeback was skipped for this track or account.
  Future<bool?> write({
    required int workId,
    required String? mediaUrl,
    required String trackPath,
    required String content,
  }) async {
    final media = mediaUrl == null ? null : Uri.tryParse(mediaUrl);
    if (media == null ||
        media.scheme != _endpoint.scheme ||
        media.host != _endpoint.host ||
        media.port != _endpoint.port ||
        media.userInfo.isNotEmpty ||
        trackPath.isEmpty) {
      return null;
    }
    final mediaPrefix = _endpoint.resolve('.').path;
    if (!media.path.startsWith(mediaPrefix)) return null;
    final route = _mediaRoute.firstMatch(
      media.path.substring(mediaPrefix.length),
    );
    if (route == null || int.tryParse(route[1]!) != workId) return null;
    final supported = await check();
    if (supported != true) return supported;
    final uri = _endpoint.replace(
      path: '${_endpoint.path}/$workId',
      queryParameters: {'trackPath': trackPath},
    );
    final request = http.Request('PUT', uri)
      ..headers['Content-Type'] = 'text/plain; charset=utf-8'
      ..body = content;
    try {
      final response = await _access.send(request);
      if (response.statusCode == 204) {
        _access.status = KikoeruWritebackStatus.allowed;
        return true;
      }
      _access.status = _access.failure(response);
      return false;
    } on Exception {
      // A transport failure applies to the site. Keep saving later tracks locally.
      _supported = Future.value(null);
      _access.status = KikoeruWritebackStatus.networkError;
      return false;
    }
  }

  Future<bool?> _probe() async {
    final result = await _access.check();
    if (result == KikoeruWritebackStatus.allowed) return true;
    if (const {
      KikoeruWritebackStatus.disabled,
      KikoeruWritebackStatus.unsupported,
    }.contains(result)) {
      return null;
    }
    return false;
  }

  void close() => _access.close();
}
