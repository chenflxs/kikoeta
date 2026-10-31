// Run with `dart run checks/webdav_live_check.dart`, supplying a single JSON
// line on stdin with url, username, password. No credentials are written.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:kikoeta_app/services/portable_backup.dart';
import 'package:kikoeta_app/services/webdav_client.dart';

Future<void> main() async {
  final input = jsonDecode(stdin.readLineSync()!) as Map;
  final folder = 'Kikoeta-test-${DateTime.now().microsecondsSinceEpoch}';
  final client = WebDavClient(
    WebDavConfig(
      url: input['url'] as String,
      username: input['username'] as String,
      password: input['password'] as String,
      folder: folder,
    ),
    createClient: () => _TraceClient(),
  );
  var created = false;
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  try {
    final create = await client.request('MKCOL', client.config.directory);
    check(create.statusCode == 201, 'Unique test directory was not created');
    created = true;
    await client.testConnection();
    stdout.writeln('Connection probe: round-trip and cleanup passed.');
    check(
      await client.read() == null,
      'New directory unexpectedly contains a backup',
    );
    final sample = <String, String>{
      'blacklist': '[{"type":"va","value":"test-only"}]',
      'playlists':
          '{"test":[{"rj":"RJ00000000","title":"test","circle":"test","tracks":[]}]}',
      'play_history':
          '[{"rj":"RJ00000000","title":"test","circle":"test","at":1}]',
      'theme': 'dark',
    };
    final backup = PortableBackup.capture((key) => sample[key]);
    await client.write(await backup.encode(), etag: null, create: true);
    final first = (await client.read())!;
    check(
      (await PortableBackup.decode(first.bytes)).fingerprint ==
          backup.fingerprint,
      'Backup round-trip mismatch',
    );
    var protected = false;
    try {
      await client.write(first.bytes, etag: null, create: true);
    } on WebDavException catch (e) {
      protected = e.code == 'webdavConflict';
    }
    check(
      protected,
      'Create-only write did not prevent replacing an existing file',
    );
    sample['theme'] = 'light';
    final changed = PortableBackup.capture((key) => sample[key]);
    await client.write(await changed.encode(), etag: first.etag, create: false);
    final second = (await client.read())!;
    check(
      (await PortableBackup.decode(second.bytes)).fingerprint ==
          changed.fingerprint,
      'Conditional update mismatch',
    );
    protected = false;
    try {
      await client.write(
        await backup.encode(),
        etag: first.etag,
        create: false,
      );
    } on WebDavException catch (e) {
      protected = e.code == 'webdavConflict';
    }
    check(
      protected,
      'Stale If-Match did not prevent overwriting remote changes',
    );
    stdout.writeln(
      'Backup upload/download, conditional update and stale-write protection passed.',
    );
  } finally {
    if (created) {
      final deletedFile = await client.request('DELETE', client.fileUri);
      check(
        [200, 204, 404].contains(deletedFile.statusCode),
        'Test backup cleanup failed',
      );
      final deletedDir = await client.request(
        'DELETE',
        client.config.directory,
      );
      check(
        [200, 204, 404].contains(deletedDir.statusCode),
        'Test directory cleanup failed',
      );
      final verify = await client.request(
        'PROPFIND',
        client.config.directory,
        headers: {'Depth': '0'},
      );
      check(verify.statusCode == 404, 'Test directory still exists');
      stdout.writeln(
        'Cleanup verified: test backup and directory both absent (HTTP 404).',
      );
    }
  }
}

class _TraceClient extends http.BaseClient {
  final _client = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final result = await _client.send(request);
    stdout.writeln(
      '${request.method} ${request.url.path}: ${result.statusCode}',
    );
    return result;
  }

  @override
  void close() => _client.close();
}
