import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'portable_backup.dart';

class WebDavException implements Exception {
  final String code;
  final int? status;
  const WebDavException(this.code, [this.status]);
  @override
  String toString() => status == null ? code : '$code (HTTP $status)';
}

class WebDavConfig {
  final String url;
  final String username;
  final String password;
  final String folder;
  const WebDavConfig({
    required this.url,
    required this.username,
    required this.password,
    this.folder = 'Kikoeta',
  });

  Uri get directory {
    final base = Uri.tryParse(url.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        username.trim().isEmpty ||
        username.contains(':') ||
        password.isEmpty ||
        folder.isEmpty ||
        folder == '.' ||
        folder == '..' ||
        folder.contains(RegExp(r'[/\\]'))) {
      throw const WebDavException('webdavInvalidConfig');
    }
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((s) => s.isNotEmpty),
        folder,
        '',
      ],
    );
  }
}

class WebDavFile {
  final Uint8List bytes;
  final String? etag;
  const WebDavFile(this.bytes, this.etag);
}

/// RFC 4918 collections and RFC 9110 conditional writes. No redirect may
/// forward the Basic credential. A fresh client bounds each operation's life.
class WebDavClient {
  final WebDavConfig config;
  final http.Client Function() _createClient;
  WebDavClient(this.config, {http.Client Function()? createClient})
    : _createClient =
          createClient ??
          (() => IOClient(
            HttpClient()..connectionTimeout = const Duration(seconds: 15),
          ));

  Uri get fileUri => config.directory.resolve('backup-v1.json');

  Future<http.Response> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? bytes,
  }) async {
    final client = _createClient();
    try {
      return await (() async {
        final request = http.Request(method, uri)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization':
                'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
            ...headers,
          });
        if (bytes != null) request.bodyBytes = bytes;
        final response = await client.send(request);
        if ((response.contentLength ?? 0) > PortableBackup.maxBytes) {
          throw const WebDavException('backupTooLarge');
        }
        final body = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          body.add(chunk);
          if (body.length > PortableBackup.maxBytes) {
            throw const WebDavException('backupTooLarge');
          }
        }
        return http.Response.bytes(
          body.takeBytes(),
          response.statusCode,
          headers: response.headers,
        );
      })().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const WebDavException('webdavTimeout');
    } on http.ClientException {
      throw const WebDavException('webdavNetworkError');
    } on SocketException {
      throw const WebDavException('webdavNetworkError');
    } on HandshakeException {
      throw const WebDavException('webdavNetworkError');
    } finally {
      client.close();
    }
  }

  void _check(http.Response response, Set<int> accepted) {
    if (accepted.contains(response.statusCode)) return;
    throw WebDavException(switch (response.statusCode) {
      401 || 403 => 'webdavAuthError',
      412 => 'webdavConflict',
      429 => 'webdavRateLimited',
      _ => 'webdavRequestFailed',
    }, response.statusCode);
  }

  Future<void> ensureDirectory() async {
    final response = await request('MKCOL', config.directory);
    _check(response, {201, 405});
  }

  Future<WebDavFile?> read() async {
    final response = await request('GET', fileUri);
    if (response.statusCode == 404) return null;
    _check(response, {200});
    return WebDavFile(response.bodyBytes, response.headers['etag']);
  }

  Future<void> write(
    List<int> bytes, {
    required String? etag,
    required bool create,
  }) async {
    if (create) {
      final nonce = List.generate(
        16,
        (_) => Random.secure().nextInt(256),
      ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
      final temp = config.directory.resolve('upload-$nonce.json');
      try {
        _check(
          await request(
            'PUT',
            temp,
            bytes: bytes,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'If-None-Match': '*',
            },
          ),
          {200, 201, 204},
        );
        // RFC 4918 MOVE with Overwrite:F publishes a new backup without
        // replacing one created concurrently. Nutstore ignores If-None-Match:*.
        final published = await request(
          'MOVE',
          temp,
          headers: {'Destination': fileUri.toString(), 'Overwrite': 'F'},
        );
        if (published.statusCode == 409) {
          throw const WebDavException('webdavConflict', 409);
        }
        _check(published, {201, 204});
      } finally {
        _check(await request('DELETE', temp), {200, 204, 404});
      }
      return;
    }
    if (!create && (etag == null || etag.startsWith('W/'))) {
      throw const WebDavException('webdavNoEtag');
    }
    final response = await request(
      'PUT',
      fileUri,
      bytes: bytes,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        if (create) 'If-None-Match': '*' else 'If-Match': etag!,
      },
    );
    _check(response, {200, 201, 204});
  }

  /// Initializes the actual sync folder, then removes a unique synthetic file.
  /// Never creates temporary top-level collections (Nutstore cannot delete them).
  Future<void> testConnection() async {
    await ensureDirectory();
    final uri = config.directory.resolve(
      'connection-test-${DateTime.now().microsecondsSinceEpoch}.json',
    );
    final bytes = utf8.encode('{"kikoeta":"connection-test"}');
    var attempted = false;
    try {
      attempted = true;
      final put = await request(
        'PUT',
        uri,
        bytes: bytes,
        headers: {'If-None-Match': '*', 'Content-Type': 'application/json'},
      );
      if (put.statusCode == 412) attempted = false;
      _check(put, {200, 201, 204});
      final get = await request('GET', uri);
      _check(get, {200});
      if (base64Encode(get.bodyBytes) != base64Encode(bytes)) {
        throw const WebDavException('webdavRequestFailed');
      }
    } finally {
      if (attempted) {
        final deleted = await request('DELETE', uri);
        _check(deleted, {200, 204, 404});
        final verify = await request('GET', uri);
        if (verify.statusCode != 404) {
          throw const WebDavException('webdavCleanupFailed');
        }
      }
    }
  }
}
