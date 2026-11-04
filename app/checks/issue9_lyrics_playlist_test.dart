// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/pages/settings_page.dart';
import 'package:kikoeta_app/services/api_service.dart';
import 'package:kikoeta_app/services/lyrics_hub.dart';
import 'package:kikoeta_app/services/portable_backup.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';

class _SettingsApi extends RustLibApi {
  final values = <String, String>{};
  final workRequests = <String>[];
  late Future<String> Function(String id) loadWork;
  @override
  Future<String> crateApiKikoeruApiApiGetWorkV2({
    required String base,
    required String rj,
  }) {
    workRequests.add(rj);
    return loadWork(rj);
  }

  @override
  String? crateApiSimpleGetSetting({required String key}) => values[key];
  @override
  void crateApiSimpleSetSetting({required String key, required String value}) =>
      values[key] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _work = Work(
  rj: 'RJ123456',
  title: 'work',
  circle: '',
  va: '',
  age: Age.r18,
  dur: '',
  tags: [],
  grad: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _SettingsApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.values.clear();
    api.workRequests.clear();
    api.loadWork = (_) async => throw StateError('offline');
  });

  const unknown = Work(
    rj: 'RJ00123456',
    title: 'saved title',
    circle: '',
    va: '',
    age: Age.all,
    ageKnown: false,
    dur: '',
    tags: [],
    grad: 0,
  );

  test(
    'playback fetches missing age once and persists it in queue and playlist',
    () async {
      final app = AppState();
      final restored = AppState();
      addTearDown(app.dispose);
      addTearDown(restored.dispose);
      app.addWorkToPlaylist('old', unknown, [
        const PlaylistTrack(title: 'one', path: 'one'),
      ]);
      app.startPlayback(unknown, const [
        MediaNode(title: 'one', type: 'file', path: 'one', work: unknown),
        MediaNode(title: 'two', type: 'file', path: 'two', work: unknown),
      ]);
      final response = Completer<String>();
      api.loadWork = (_) => response.future;
      final first = ApiService.ensurePlaybackAge(app);
      final duplicate = ApiService.ensurePlaybackAge(app);
      expect(api.workRequests, ['123456']);
      response.complete('{"id":123456,"nsfw":true}');
      await Future.wait([first, duplicate]);
      expect(app.currentWork!.age, Age.r18);
      expect(app.currentWork!.ageKnown, isTrue);
      expect(app.currentWork!.rj, unknown.rj);
      expect(app.currentWork!.title, unknown.title);
      expect(app.queue.every((node) => node.work!.age == Age.r18), isTrue);
      expect(app.playlists['old']!.single.age, Age.r18);
      await ApiService.ensurePlaybackAge(app);
      expect(api.workRequests, hasLength(1));
      restored.restorePlayState(api.values['play_state']);
      expect(restored.currentWork!.age, Age.r18);
      await restored.loadFromRust(restorePlayback: false);
      expect(restored.playlists['old']!.single.age, Age.r18);
    },
  );

  test(
    'late age response does not replace the work selected after a track switch',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      app.startPlayback(unknown, const [
        MediaNode(title: 'one', type: 'file', path: 'one', work: unknown),
        MediaNode(title: 'other', type: 'file', path: 'other', work: _work),
      ]);
      final response = Completer<String>();
      api.loadWork = (_) => response.future;
      final pending = ApiService.ensurePlaybackAge(app);
      app.trackIdx = 1;
      response.complete('{"id":123456,"nsfw":false}');
      await pending;
      expect(app.currentWork, same(_work));
      expect(app.currentWork!.age, Age.r18);
      app.trackIdx = 0;
      expect(app.currentWork!.ageKnown, isTrue);
      expect(app.currentWork!.age, Age.all);
    },
  );

  test(
    'failed or missing metadata can retry without assuming all ages',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      app.startPlayback(unknown, const [
        MediaNode(title: 'one', type: 'file', path: 'one'),
      ]);
      await ApiService.ensurePlaybackAge(app);
      expect(app.currentWork!.ageKnown, isFalse);
      expect(app.playing, isTrue);
      api.loadWork = (_) async => '{"id":123456}';
      await ApiService.ensurePlaybackAge(app);
      expect(app.currentWork!.ageKnown, isFalse);
      api.loadWork = (_) async => '{"id":123456,"age_category_string":"r15"}';
      await ApiService.ensurePlaybackAge(app);
      expect(app.currentWork!.age, Age.r15);
      expect(app.currentWork!.ageKnown, isTrue);
      expect(api.workRequests, hasLength(3));
    },
  );

  test(
    'age response from a server left during the request is ignored',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      app.startPlayback(unknown, const [
        MediaNode(title: 'one', type: 'file', path: 'one'),
      ]);
      final response = Completer<String>();
      api.loadWork = (_) => response.future;
      final pending = ApiService.ensurePlaybackAge(app);
      app.customServer = true;
      app.customSites.add(
        CustomSite(alias: 'other', url: 'https://other.test'),
      );
      response.complete('{"id":123456,"nsfw":true}');
      await pending;
      expect(app.currentWork!.ageKnown, isFalse);
    },
  );

  testWidgets('blank-line switch fits and works in each supported language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState();
    addTearDown(app.dispose);
    for (final locale in AppLocalizations.supportedLocales) {
      app.setLyricsSkipEmpty(false);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(locale),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(app: app, sectionKey: 'lyrics_desktop'),
        ),
      );
      await tester.pumpAndSettle();
      final strings = lookupAppLocalizations(locale);
      final row = find
          .ancestor(
            of: find.text(strings.lyricsSkipEmpty),
            matching: find.byType(Row),
          )
          .first;
      final toggle = find.descendant(of: row, matching: find.byType(Switch));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(app.lyricsSkipEmpty, isTrue);
      expect(api.values['lyrics_skip_empty'], '1');
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  test('playlist age survives save, reload and adding more tracks', () async {
    final app = AppState();
    final restored = AppState();
    addTearDown(app.dispose);
    addTearDown(restored.dispose);
    app.addWorkToPlaylist('list', _work, [
      const PlaylistTrack(title: 'one', path: 'one', url: 'https://test/one'),
    ]);
    app.addWorkToPlaylist('list', _work, [
      const PlaylistTrack(title: 'two', path: 'two'),
    ]);
    await restored.loadFromRust(restorePlayback: false);
    expect(restored.playlists['list']!.single.age, Age.r18);
    expect(restored.playlists['list']!.single.tracks, hasLength(2));
    final backup = PortableBackup.capture((key) => api.values[key]);
    final roundtrip = await PortableBackup.decode(await backup.encode());
    expect(
      jsonDecode(roundtrip.settings['playlists']!)['list'][0]['age'],
      'r18',
    );
  });

  test(
    'legacy playlist age stays unknown instead of becoming all ages',
    () async {
      api.values['playlists'] =
          '{"old":[{"rj":"RJ123456","title":"old","circle":"","tracks":["one"]}]}';
      final app = AppState();
      addTearDown(app.dispose);
      await app.loadFromRust(restorePlayback: false);
      expect(app.playlists['old']!.single.age, isNull);
      app.rememberPlaylistAge(_work);
      expect(app.playlists['old']!.single.age, Age.r18);
      final restored = AppState();
      addTearDown(restored.dispose);
      await restored.loadFromRust(restorePlayback: false);
      expect(restored.playlists['old']!.single.age, Age.r18);
    },
  );

  test('cross-work playlist keeps ownership through switching and restart', () {
    const other = Work(
      rj: 'RJ654321',
      title: 'all ages',
      circle: '',
      va: '',
      age: Age.all,
      dur: '',
      tags: [],
      grad: 0,
    );
    final app = AppState();
    final restored = AppState();
    addTearDown(app.dispose);
    addTearDown(restored.dispose);
    app.startPlayback(_work, const [
      MediaNode(title: 'adult', type: 'file', path: 'same.mp3', work: _work),
      MediaNode(title: 'all ages', type: 'file', path: 'same.mp3', work: other),
    ]);
    final structure = api.values['play_state'];
    expect(app.currentWork!.age, Age.r18);
    app.trackIdx = 1;
    expect(app.currentWork!.rj, other.rj);
    expect(app.currentWork!.age, Age.all);
    app.savePlayState();
    expect(api.values['play_state'], structure);
    restored.restorePlayState(
      structure,
      checkpoint: api.values['play_state_position'],
    );
    expect(restored.currentWork!.rj, other.rj);
    expect(restored.currentWork!.age, Age.all);
    restored.trackIdx = 0;
    expect(restored.currentWork!.age, Age.r18);
    restored.currentWork = null;
    expect(restored.currentWork, isNull);
  });

  test(
    'blank filtering extends cue timing and can restore original lines',
    () async {
      var pos = const Duration(seconds: 6);
      final app = AppState()
        ..currentWork = _work
        ..queue = const [MediaNode(title: 'one', type: 'file', path: 'one')];
      final hub = LyricsHub.forTesting(
        libraryMatcher: (_) async => [],
        libraryLoader: (_) async => [],
        onlineLoader: (_, _) async => const [
          LyricLine(0, '', ''),
          LyricLine(2, 'first', '第一句'),
          LyricLine(5, ' \t ', ''),
          LyricLine(8, 'second', '第二句'),
          LyricLine(10, '', ''),
        ],
        position: () => pos,
        duration: () => const Duration(seconds: 20),
      );
      addTearDown(hub.dispose);
      addTearDown(app.dispose);
      hub.bind(app);
      await Future<void>.delayed(Duration.zero);
      expect(hub.lyrics, hasLength(5));
      app.setLyricsSkipEmpty(true);
      expect(hub.lyrics, hasLength(2));
      expect(hub.currentLine, 'first');
      expect(
        hub.currentOverlayCue.timing!.duration,
        const Duration(seconds: 6),
      );
      pos = const Duration(seconds: 12);
      expect(hub.currentLine, 'second');
      expect(hub.currentOverlayCue.timing!.end, const Duration(seconds: 20));
      app.setLyricsSkipEmpty(false);
      expect(hub.lyrics, hasLength(5));
      expect(hub.currentLine, '');
      app.setLyricsSkipEmpty(true);
      final restored = AppState();
      addTearDown(restored.dispose);
      await restored.loadFromRust(restorePlayback: false);
      expect(restored.lyricsSkipEmpty, isTrue);
    },
  );

  test(
    'filter follows selected language and handles all-blank lyrics',
    () async {
      final app = AppState()
        ..currentWork = _work
        ..queue = const [MediaNode(title: 'one', type: 'file', path: 'one')]
        ..lyricsSkipEmpty = true;
      var lines = const [LyricLine(0, 'original only', '')];
      final hub = LyricsHub.forTesting(
        libraryMatcher: (_) async => [],
        libraryLoader: (_) async => [],
        onlineLoader: (_, _) async => lines,
      );
      addTearDown(hub.dispose);
      addTearDown(app.dispose);
      hub.bind(app);
      await Future<void>.delayed(Duration.zero);
      expect(hub.lyrics, hasLength(1));
      app.setConv('zh');
      expect(hub.lyrics, isEmpty);
      expect(hub.currentOverlayCue.timing, isNull);
      app.setConv('orig');
      expect(hub.currentLine, 'original only');
      lines = const [LyricLine(0, ' \n ', ''), LyricLine(1, '', '')];
      await hub.loadManualLyrics(hub.captureSelection()!, () async => lines);
      expect(hub.lyrics, isEmpty);
      expect(hub.currentLine, '');
    },
  );
}
