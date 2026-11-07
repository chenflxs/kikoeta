import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/kikoeru_lyrics_writeback.dart';

void main() {
  const trackPath = '特典/01 音声 + #.mp3';
  const lyric = '[00:01.230] 字幕\n';
  const key = 'ABcd1234EFgh5678';
  const headers = {'Authorization': 'Bearer test-token'};
  late HttpServer server;
  late KikoeruLyricsWriteback writer;
  late String base;
  late List<String> requests;
  late String? capability;
  late int probeStatus;
  late int writeStatus;
  String? expectedAuthorization;
  String? expectedKey;

  setUp(() async {
    requests = [];
    capability = '2';
    probeStatus = 204;
    writeStatus = 204;
    expectedAuthorization = 'Bearer test-token';
    expectedKey = key;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}/library';
    writer = KikoeruLyricsWriteback.connect(base, headers, key: key)!;
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      expect(request.headers.value('authorization'), expectedAuthorization);
      expect(request.headers.value('X-Kikoeru-Writeback-Key'), expectedKey);
      expect(request.uri.queryParameters.values, isNot(contains(key)));
      if (request.method == 'HEAD') {
        if (capability != null) {
          request.response.headers.set(
            'X-Kikoeru-Lyrics-Writeback',
            capability!,
          );
        }
        request.response.statusCode = probeStatus;
      } else {
        expect(request.uri.queryParameters['trackPath'], trackPath);
        expect(request.headers.contentType?.mimeType, 'text/plain');
        expect(await utf8.decoder.bind(request).join(), lyric);
        request.response.statusCode = writeStatus;
        if (writeStatus == 307) {
          request.response.headers.set('location', '/redirected');
        }
      }
      await request.response.close();
    });
    addTearDown(() => writer.close());
    addTearDown(() => server.close(force: true));
  });

  Future<bool?> write({String? url}) => writer.write(
    workId: 123456,
    mediaUrl: url ?? '$base/api/media/download/123456/0',
    trackPath: trackPath,
    content: lyric,
  );

  test('probes once and delivers the exact path and UTF-8 content', () async {
    expect(await write(), isTrue);
    expect(await write(), isTrue);
    expect(requests, [
      'HEAD /library/api/media/kikoeta-lyrics',
      'PUT /library/api/media/kikoeta-lyrics/123456',
      'PUT /library/api/media/kikoeta-lyrics/123456',
    ]);
  });

  test('does not send lyrics when the original site lacks support', () async {
    capability = null;
    expect(await write(), isNull);
    expect(await write(), isNull);
    expect(requests, ['HEAD /library/api/media/kikoeta-lyrics']);
  });

  test('does not upload to an older server without key enforcement', () async {
    capability = '1';
    expect(await write(), isNull);
    expect(requests, ['HEAD /library/api/media/kikoeta-lyrics']);
  });

  test(
    'rejected credentials keep lyrics local without sending a PUT',
    () async {
      probeStatus = 403;
      expect(await write(), isFalse);
      expect(await write(), isFalse);
      expect(requests, ['HEAD /library/api/media/kikoeta-lyrics']);
    },
  );

  test('skips external media, another library and another work', () async {
    expect(await write(url: 'https://example.org/123456/0'), isNull);
    expect(
      await write(url: '$base/../other/api/media/download/123456/0'),
      isNull,
    );
    expect(await write(url: '$base/api/media/download/654321/0'), isNull);
    expect(requests, isEmpty);
  });

  test('reports write failure without following redirects', () async {
    for (final status in [403, 404, 409, 500, 307]) {
      writeStatus = status;
      expect(await write(), isFalse);
    }
    expect(requests, hasLength(6));
    expect(requests, isNot(contains('PUT /redirected')));
  });

  test('skips missing and non-HTTP sources', () {
    expect(KikoeruLyricsWriteback.connect(null, headers, key: key), isNull);
    expect(
      KikoeruLyricsWriteback.connect('file:///tmp', headers, key: key),
      isNull,
    );
  });

  test('validates optional keys as exactly 16 ASCII letters or digits', () {
    for (final invalid in [
      '',
      '123456789012345',
      '${key}a',
      '123456789012345\n',
      '123456789012345密',
    ]) {
      expect(KikoeruLyricsWriteback.isValidKey(invalid), isFalse);
    }
    expect(requests, isEmpty);
  });

  test(
    'uploads without credentials or key when the server permits it',
    () async {
      writer.close();
      writer = KikoeruLyricsWriteback.connect(base, {}, key: '')!;
      expectedAuthorization = null;
      expectedKey = null;
      expect(await write(), isTrue);
      expect(requests, [
        'HEAD /library/api/media/kikoeta-lyrics',
        'PUT /library/api/media/kikoeta-lyrics/123456',
      ]);
    },
  );

  test('keeps lyrics local if a protected server requires login', () async {
    writer.close();
    writer = KikoeruLyricsWriteback.connect(base, {}, key: '')!;
    expectedAuthorization = null;
    expectedKey = null;
    probeStatus = 401;
    expect(await write(), isFalse);
    expect(requests, ['HEAD /library/api/media/kikoeta-lyrics']);
  });
}
