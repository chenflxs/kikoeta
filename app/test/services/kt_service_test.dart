import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kikoeta_app/services/kt_service.dart';

void main() {
  group('KtService endpoint', () {
    test('adds http scheme to host and port', () {
      expect(
        KtService.normalizeEndpoint('192.168.1.20:2370'),
        'http://192.168.1.20:2370',
      );
    });

    test('keeps https and removes trailing slash', () {
      expect(
        KtService.normalizeEndpoint('https://kt.example.test:443/'),
        'https://kt.example.test',
      );
    });

    test('rejects an empty endpoint', () {
      expect(() => KtService.normalizeEndpoint(' '), throwsFormatException);
    });

    test('requires an explicit port', () {
      expect(
        () => KtService.normalizeEndpoint('kt.example.test'),
        throwsFormatException,
      );
    });
  });

  test('lyrics are stored below the normalized RJ directory', () {
    expect(
      ktLyricsRelativePath('rj123', r'folder\track 01.mp3'),
      'RJ123/folder/track 01.zh.lrc',
    );
    expect(
      ktLyricsRelativePath('RJ123', '../bad/<track>.wav'),
      'RJ123/bad/_track_.zh.lrc',
    );
  });

  test('all kt requests carry Basic authentication', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final service = KtService(
      '127.0.0.1:2370',
      username: 'listener',
      password: 'secret',
      client: client,
    );

    await service.health();
    await service.createJob(const []);

    final expected = 'Basic ${base64Encode(utf8.encode('listener:secret'))}';
    expect(requests, hasLength(2));
    expect(
      requests.every((r) => r.headers['authorization'] == expected),
      isTrue,
    );
    service.close();
  });

  test('cache results retain the work and source-track mapping', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/cache');
      return http.Response(
        jsonEncode({
          'entries': [
            {
              'job_id': 'cached-job',
              'work_id': 'RJ123',
              'files': [
                {
                  'track_path': 'disc/01.mp3',
                  'name': '01.zh.lrc',
                  'download_url': '/api/v1/cache/cached-job/files/0',
                },
              ],
            },
          ],
        }),
        200,
      );
    });
    final service = KtService('127.0.0.1:2370', client: client);

    final entries = await service.cachedResults();

    expect(entries, hasLength(1));
    expect(entries.single.workId, 'RJ123');
    expect(entries.single.files.single.trackPath, 'disc/01.mp3');
    service.close();
  });
}
