import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/services/portable_backup.dart';
import 'package:kikoeta_app/services/settings_store.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';

class _MemoryApi extends RustLibApi {
  final values = <String, String>{};
  String? failKey;
  @override
  String? crateApiSimpleGetSetting({required String key}) => values[key];
  @override
  void crateApiSimpleSetSetting({required String key, required String value}) {
    if (key == failKey) throw StateError('simulated write failure');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _MemoryApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.values.clear();
    api.failKey = null;
  });

  test(
    'interrupted import rolls forward before loading, preserving excluded data',
    () {
      api.values.addAll({
        'blacklist': '[{"type":"rj","value":"old"}]',
        'asmr_pass': 'secret',
        'downloads': 'large',
        'webdav_password': 'secret',
      });
      final snapshot = PortableBackup.capture((_) => null);
      api.failKey = 'playlists';
      expect(
        () => SettingsStore.importPortable(snapshot.settings),
        throwsStateError,
      );
      expect(api.values['portable_import_journal'], isNotEmpty);
      api.failKey = null;
      SettingsStore.recoverPendingImport();
      for (final e in snapshot.settings.entries) {
        expect(api.values[e.key], e.value);
      }
      expect(api.values['portable_import_journal'], '');
      expect(api.values['asmr_pass'], 'secret');
      expect(api.values['downloads'], 'large');
      expect(api.values['webdav_password'], 'secret');
    },
  );

  test(
    'import applies empty collections, disables SFW and keeps current playback',
    () async {
      final app = AppState();
      app.sfwMode = true;
      app.ageFilters.add(0);
      app.playing = true;
      app.trackIdx = 1;
      app.resumePosition = 50;
      app.queue = const [
        MediaNode(title: 'current', type: 'file', path: 'current'),
      ];
      app.blacklist.add({'type': 'rj', 'value': 'old'});
      app.favoriteRjs.add('old');
      final snapshot = PortableBackup.capture(
        (k) => k == 'theme' ? 'dark' : null,
      );
      SettingsStore.importPortable(snapshot.settings);
      await app.loadFromRust(restorePlayback: false);
      expect(app.sfwMode, isFalse);
      expect(app.ageFilters, isEmpty);
      expect(app.blacklist, isEmpty);
      expect(app.favoriteRjs, isEmpty);
      expect(app.themeMode, ThemeMode.dark);
      expect(app.playing, isTrue);
      expect(app.trackIdx, 1);
      expect(app.resumePosition, 50);
      expect(app.queue.single.path, 'current');
      app.dispose();
    },
  );
}
