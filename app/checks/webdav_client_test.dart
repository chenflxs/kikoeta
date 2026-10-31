import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kikoeta_app/services/portable_backup.dart';
import 'package:kikoeta_app/services/webdav_client.dart';

const config = WebDavConfig(
  url: 'https://example.com/dav/',
  username: 'user',
  password: 'private',
);
void main() {
  test(
    'new backup publishes with MOVE Overwrite F and cleans the temporary file',
    () async {
      final calls = <http.Request>[];
      final client = WebDavClient(
        config,
        createClient: () => MockClient((r) async {
          calls.add(r);
          return http.Response(
            '',
            r.method == 'PUT' || r.method == 'MOVE' ? 201 : 204,
          );
        }),
      );
      await client.write(utf8.encode('{}'), etag: null, create: true);
      expect(calls.map((r) => r.method), ['PUT', 'MOVE', 'DELETE']);
      expect(calls[1].headers['Overwrite'], 'F');
      expect(calls[1].headers['Destination'], client.fileUri.toString());
      expect(calls[2].url, calls[0].url);
      expect(calls[0].followRedirects, isFalse);
    },
  );

  test(
    'MOVE collisions preserve the existing backup and remove the temporary upload',
    () async {
      final methods = <String>[];
      final client = WebDavClient(
        config,
        createClient: () => MockClient((r) async {
          methods.add(r.method);
          return http.Response(
            '',
            r.method == 'MOVE'
                ? 409
                : r.method == 'PUT'
                ? 201
                : 204,
          );
        }),
      );
      await expectLater(
        client.write([], etag: null, create: true),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.code,
            'code',
            'webdavConflict',
          ),
        ),
      );
      expect(methods.last, 'DELETE');
    },
  );

  test(
    'updates include the exact ETag and stale writes surface a conflict',
    () async {
      final client = WebDavClient(
        config,
        createClient: () => MockClient((r) async {
          expect(r.headers['If-Match'], '"old"');
          return http.Response('', 412);
        }),
      );
      await expectLater(
        client.write([], etag: '"old"', create: false),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.code,
            'code',
            'webdavConflict',
          ),
        ),
      );
      await expectLater(
        client.write([], etag: null, create: false),
        throwsA(
          isA<WebDavException>().having((e) => e.code, 'code', 'webdavNoEtag'),
        ),
      );
    },
  );

  test(
    'connection probe cleans synthetic data even when its read fails',
    () async {
      final methods = <String>[];
      var gets = 0;
      final client = WebDavClient(
        config,
        createClient: () => MockClient((r) async {
          methods.add(r.method);
          if (r.method == 'GET') {
            return http.Response('', ++gets == 1 ? 500 : 404);
          }
          return http.Response('', r.method == 'DELETE' ? 204 : 201);
        }),
      );
      await expectLater(
        client.testConnection(),
        throwsA(isA<WebDavException>()),
      );
      expect(methods, ['MKCOL', 'PUT', 'GET', 'DELETE', 'GET']);
    },
  );

  test(
    'invalid endpoints cannot leak authentication through URL credentials or redirects',
    () {
      for (final url in [
        'http://example.com/dav',
        'https://u:p@example.com/dav',
        'https://example.com/dav?key=secret',
      ]) {
        expect(
          () => WebDavConfig(url: url, username: 'u', password: 'p').directory,
          throwsA(isA<WebDavException>()),
        );
      }
      expect(
        () => const WebDavConfig(
          url: 'https://example.com',
          username: 'u',
          password: 'p',
          folder: '../other',
        ).directory,
        throwsA(isA<WebDavException>()),
      );
    },
  );

  test(
    'server authentication and size failures produce safe bounded errors',
    () async {
      final auth = WebDavClient(
        config,
        createClient: () => MockClient((_) async => http.Response('', 401)),
      );
      await expectLater(
        auth.read(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.code,
            'code',
            'webdavAuthError',
          ),
        ),
      );
      final huge = WebDavClient(
        config,
        createClient: () => MockClient.streaming(
          (_, _) async => http.StreamedResponse(const Stream.empty(), 200,
            contentLength: PortableBackup.maxBytes + 1),
        ),
      );
      await expectLater(
        huge.read(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.code,
            'code',
            'backupTooLarge',
          ),
        ),
      );
    },
  );
}
