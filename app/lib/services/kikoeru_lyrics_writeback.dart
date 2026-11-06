import 'dart:async';

import 'package:http/http.dart' as http;

/// Writes a copy to the original self-hosted site after the local save.
class KikoeruLyricsWriteback {
  KikoeruLyricsWriteback._(this._endpoint, this._headers, this._client);

  static const _timeout = Duration(seconds: 4);
  static final _mediaRoute = RegExp(r'^(?:download|stream)/([0-9]+)/[0-9]+$');
  static final _keyPattern = RegExp(r'^[A-Za-z0-9]{16}$');
  final Uri _endpoint;
  final Map<String, String> _headers;
  final http.Client _client;
  Future<bool?>? _supported;

  static bool isValidKey(String key) =>
      key.length == 16 && _keyPattern.hasMatch(key);

  static KikoeruLyricsWriteback? connect(
    String? sourceBase,
    Map<String, String> headers, {
    required String key,
  }) {
    final base = sourceBase == null ? null : Uri.tryParse(sourceBase);
    if (base == null ||
        !const {'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !headers.containsKey('Authorization') ||
        !isValidKey(key)) {
      return null;
    }
    final path = base.path.replaceFirst(RegExp(r'/+$'), '');
    final endpoint = base.replace(path: '$path/api/media/kikoeta-lyrics');
    return KikoeruLyricsWriteback._(endpoint, {
      'Authorization': headers['Authorization']!,
      'X-Kikoeru-Writeback-Key': key,
    }, http.Client());
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
    final supported = await (_supported ??= _probe());
    if (supported != true) return supported;
    final uri = _endpoint.replace(
      path: '${_endpoint.path}/$workId',
      queryParameters: {'trackPath': trackPath},
    );
    final request = http.Request('PUT', uri)
      ..headers['Content-Type'] = 'text/plain; charset=utf-8'
      ..body = content;
    try {
      return (await _send(request)).statusCode == 204;
    } on Exception {
      // A transport failure applies to the site. Keep saving later tracks locally.
      _supported = Future.value(null);
      return false;
    }
  }

  Future<bool?> _probe() async {
    try {
      final response = await _send(http.Request('HEAD', _endpoint));
      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }
      if (response.statusCode == 204 &&
          response.headers['x-kikoeru-lyrics-writeback'] == '2') {
        return true;
      }
      return null;
    } on Exception {
      return null;
    }
  }

  Future<http.StreamedResponse> _send(http.Request request) async {
    request
      ..followRedirects = false
      ..headers.addAll(_headers);
    final response = await _client.send(request).timeout(_timeout);
    await response.stream.drain<void>().timeout(_timeout);
    return response;
  }

  void close() => _client.close();
}
