import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/portable_backup.dart';

void main() {
  test(
    'round trip keeps small local data and excludes credentials and libraries',
    () async {
      final data = <String, String>{
        'blacklist': '[{"type":"va","value":"声优"}]',
        'playlists':
            '{"歌单":[{"rj":"RJ1","title":"音声","circle":"社团","tracks":[{"title":"轨道","path":"a.mp3","url":"https://example.com/a.mp3","duration":12}]}]}',
        'play_history': '[{"rj":"RJ1","title":"音声","circle":"社团","at":100}]',
        'favs': '["RJ1"]',
        'theme': 'dark',
        'audio_channel_mode': 'swap',
        'asmr_pass': 'private',
        'webdav_password': 'private',
        'deepl_key': 'private',
        'lyrics_library_index': 'large',
        'downloads': 'large',
        'token:server': 'private',
      };
      final backup = PortableBackup.capture((key) => data[key]);
      final bytes = await backup.encode();
      final restored = await PortableBackup.decode(bytes);
      expect(restored.settings['playlists'], data['playlists']);
      expect(restored.settings['blacklist'], data['blacklist']);
      expect(restored.fingerprint, backup.fingerprint);
      expect(utf8.decode(bytes), isNot(contains('private')));
      expect(utf8.decode(bytes), isNot(contains('large')));
    },
  );

  test('damaged checksum and unknown versions are rejected', () async {
    final backup = PortableBackup.capture((_) => null);
    final raw = jsonDecode(utf8.decode(await backup.encode())) as Map;
    raw['settings']['theme'] = 'dark';
    await expectLater(
      PortableBackup.decode(utf8.encode(jsonEncode(raw))),
      throwsFormatException,
    );
    raw['version'] = 2;
    await expectLater(
      PortableBackup.decode(utf8.encode(jsonEncode(raw))),
      throwsFormatException,
    );
  });

  test(
    'valid checksums do not bypass structure and preference validation',
    () async {
      for (final invalid in [
        {'playlists': '{"bad":[{"rj":4}]}'},
        {'blacklist': '[{"type":"va","value":1}]'},
        {'play_history': '[{"rj":"RJ1","title":"a","circle":"b","at":"bad"}]'},
        {'eq_gains': '[0]'},
        {'volume': 'NaN'},
        {'theme': 'invalid'},
      ]) {
        final backup = PortableBackup.capture((key) => invalid[key]);
        await expectLater(
          PortableBackup.decode(await backup.encode()),
          throwsFormatException,
        );
      }
    },
  );

  test('oversized and non JSON backups are rejected', () async {
    await expectLater(
      PortableBackup.decode(List.filled(PortableBackup.maxBytes + 1, 0)),
      throwsFormatException,
    );
    await expectLater(
      PortableBackup.decode(utf8.encode('not json')),
      throwsFormatException,
    );
  });
}
