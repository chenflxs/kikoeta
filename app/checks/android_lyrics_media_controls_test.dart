import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/pages/settings_page.dart';
import 'package:kikoeta_app/services/android_lyrics_overlay.dart';
import 'package:kikoeta_app/services/android_media3.dart';
import 'package:kikoeta_app/services/portable_backup.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';

class _SettingsApi extends RustLibApi {
  final values = <String, String>{};
  @override
  String? crateApiSimpleGetSetting({required String key}) => values[key];
  @override
  void crateApiSimpleSetSetting({required String key, required String value}) =>
      values[key] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final api = _SettingsApi();
  const mediaChannel = MethodChannel('kikoeta/media3');
  const overlayChannel = MethodChannel('kikoeta/lyrics_overlay');
  final messenger = binding.defaultBinaryMessenger;
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() => api.values.clear());
  tearDown(() {
    AndroidMedia3.onCommand = null;
    AndroidLyricsOverlay.instance.onLockChanged = null;
    messenger.setMockMethodCallHandler(mediaChannel, null);
    messenger.setMockMethodCallHandler(overlayChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'old orientation locks migrate once, then only the shared value applies',
    () async {
      for (final legacy in [
        {'lyrics_locked_portrait': '1', 'lyrics_locked_landscape': '0'},
        {'lyrics_locked_portrait': '0', 'lyrics_locked_landscape': '1'},
        {'lyrics_locked_portrait': '0', 'lyrics_locked_landscape': '0'},
      ]) {
        api.values
          ..clear()
          ..addAll(legacy);
        final app = AppState();
        final restored = AppState();
        addTearDown(app.dispose);
        addTearDown(restored.dispose);
        await app.loadFromRust(restorePlayback: false);
        expect(app.lyricsLockedAndroid, legacy.values.contains('1'));
        expect(
          api.values['lyrics_locked_android'],
          legacy.values.contains('1') ? '1' : '0',
        );
        app.setLyricsLockedAndroid(false);
        api.values['lyrics_locked_portrait'] = '1';
        api.values['lyrics_locked_landscape'] = '1';
        await restored.loadFromRust(restorePlayback: false);
        expect(restored.lyricsLockedAndroid, isFalse);
      }
    },
  );

  test(
    'native lock events and media card operate on the same persisted lock',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      Map<Object?, Object?>? shown;
      messenger.setMockMethodCallHandler(overlayChannel, (call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'show') shown = call.arguments as Map;
        return null;
      });
      final overlay = AndroidLyricsOverlay.instance;
      overlay.onLockChanged = app.setLyricsLockedAndroid;
      await overlay.init();
      await messenger.handlePlatformMessage(
        overlayChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('lockChanged', {'locked': true}),
        ),
        (_) {},
      );
      expect(app.lyricsLockedAndroid, isTrue);
      await overlay.handleMediaCommand(app, 'lyricsLock');
      expect(app.lyricsLockedAndroid, isFalse);
      expect(api.values['lyrics_locked_android'], '0');
      await overlay.show(
        text: 'lyrics',
        fontSize: 20,
        color: 0xFFFFFFFF,
        outlineColor: 0xFF000000,
        outlineWidth: 1,
        locked: app.lyricsLockedAndroid,
      );
      expect(shown!['locked'], isFalse);
      expect(shown!.containsKey('portrait'), isFalse);
      expect(shown!.containsKey('portraitWidthDp'), isFalse);
    },
  );

  test(
    'pause visibility defaults off, persists and obeys other hide reasons',
    () async {
      final app = AppState()..desktopLyricsOn = true;
      final restored = AppState();
      addTearDown(app.dispose);
      addTearDown(restored.dispose);
      expect(app.androidLyricsHideWhenPaused, isFalse);
      expect(app.androidDesktopLyricsVisible, isTrue);
      app.setAndroidLyricsHideWhenPaused(true);
      expect(app.androidDesktopLyricsVisible, isFalse);
      app.playing = true;
      expect(app.androidDesktopLyricsVisible, isTrue);
      app.desktopLyricsTemporarilyHidden = true;
      expect(app.androidDesktopLyricsVisible, isFalse);
      app.desktopLyricsTemporarilyHidden = false;
      app.desktopLyricsOn = false;
      expect(app.androidDesktopLyricsVisible, isFalse);
      await restored.loadFromRust(restorePlayback: false);
      expect(restored.androidLyricsHideWhenPaused, isTrue);
      final backup = PortableBackup.capture((key) => api.values[key]);
      expect(
        (await PortableBackup.decode(
          await backup.encode(),
        )).settings['android_lyrics_hide_when_paused'],
        '1',
      );
      expect(PortableBackup.defaults['android_lyrics_hide_when_paused'], '0');
    },
  );

  Future<void> sendCommand(String action) async {
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      mediaChannel.name,
      codec.encodeMethodCall(
        MethodCall('command', {'action': action, 'positionMs': -1}),
      ),
      (_) {},
    );
  }

  test('media commands toggle lyrics and the shared Android lock', () async {
    final app = AppState();
    addTearDown(app.dispose);
    Future<void>? pending;
    messenger.setMockMethodCallHandler(overlayChannel, (call) async {
      expect(call.method, 'isAvailable');
      return true;
    });
    AndroidMedia3.onCommand = (action, _) {
      pending = AndroidLyricsOverlay.instance.handleMediaCommand(app, action);
    };
    await AndroidMedia3.init();
    await sendCommand('lyricsLock');
    await pending;
    expect(app.lyricsLockedAndroid, isTrue);
    expect(api.values['lyrics_locked_android'], '1');
    await sendCommand('lyricsLock');
    await pending;
    expect(app.lyricsLockedAndroid, isFalse);
    expect(api.values['lyrics_locked_android'], '0');
    await sendCommand('lyricsToggle');
    await pending;
    expect(app.desktopLyricsOn, isTrue);
    expect(api.values['desktop_lyrics'], '1');
    await sendCommand('lyricsToggle');
    await pending;
    expect(app.desktopLyricsOn, isFalse);
    expect(api.values['desktop_lyrics'], '0');
  });

  test(
    'permission failure keeps lyrics off; duplicate enable taps are combined',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      messenger.setMockMethodCallHandler(overlayChannel, (_) async {
        throw PlatformException(code: 'permission_denied');
      });
      await AndroidLyricsOverlay.instance.handleMediaCommand(
        app,
        'lyricsToggle',
      );
      expect(app.desktopLyricsOn, isFalse);
      final permission = Completer<bool>();
      var calls = 0;
      messenger.setMockMethodCallHandler(overlayChannel, (_) {
        calls++;
        return permission.future;
      });
      final first = AndroidLyricsOverlay.instance.handleMediaCommand(
        app,
        'lyricsToggle',
      );
      final duplicate = AndroidLyricsOverlay.instance.handleMediaCommand(
        app,
        'lyricsToggle',
      );
      permission.complete(true);
      await Future.wait([first, duplicate]);
      expect(calls, 1);
      expect(app.desktopLyricsOn, isTrue);
    },
  );

  test(
    'media bridge carries lyrics state and localized action labels',
    () async {
      Map<Object?, Object?>? sent;
      messenger.setMockMethodCallHandler(mediaChannel, (call) async {
        if (call.method == 'updateState') sent = call.arguments as Map;
        return null;
      });
      await AndroidMedia3.updateState(
        isPlaying: false,
        positionMs: 1000,
        durationMs: 2000,
        title: 'track',
        artist: 'work',
        mediaId: 'RJ1',
        lyricsEnabled: true,
        lyricsLocked: true,
        lyricsLockLabel: '解锁歌词',
        lyricsToggleLabel: '关闭歌词',
      );
      expect(sent!['lyricsEnabled'], isTrue);
      expect(sent!['lyricsLocked'], isTrue);
      expect(sent!['lyricsLockLabel'], '解锁歌词');
      expect(sent!['lyricsToggleLabel'], '关闭歌词');
    },
  );

  testWidgets('privacy switch starts off and fits all languages on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppState();
      addTearDown(app.dispose);
      for (final locale in AppLocalizations.supportedLocales) {
        app.setAndroidLyricsHideWhenPaused(false);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(app: app, sectionKey: 'privacy'),
          ),
        );
        await tester.pumpAndSettle();
        final title = lookupAppLocalizations(
          locale,
        ).androidLyricsHideWhenPaused;
        final row = find
            .ancestor(of: find.text(title), matching: find.byType(Row))
            .first;
        final toggle = find.descendant(of: row, matching: find.byType(Switch));
        await tester.ensureVisible(toggle);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(app.androidLyricsHideWhenPaused, isTrue);
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'Android lyrics settings expose one lock switch in either layout',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final app = AppState();
        addTearDown(app.dispose);
        for (final size in [const Size(360, 800), const Size(800, 360)]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            ListenableBuilder(
              listenable: app,
              builder: (context, _) => MaterialApp(
                key: ValueKey(size),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: SettingsPage(app: app, sectionKey: 'lyrics_desktop'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final title = lookupAppLocalizations(
            const Locale('en'),
          ).lockDesktopLyrics;
          expect(find.text(title), findsOneWidget);
          expect(find.textContaining('Android (portrait)'), findsNothing);
          expect(find.textContaining('Android (landscape)'), findsNothing);
          final row = find
              .ancestor(of: find.text(title), matching: find.byType(Row))
              .first;
          final toggle = find.descendant(
            of: row,
            matching: find.byType(Switch),
          );
          await tester.ensureVisible(toggle);
          expect(tester.widget<Switch>(toggle).value, app.lyricsLockedAndroid);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(toggle).value, app.lyricsLockedAndroid);
          expect(
            api.values['lyrics_locked_android'],
            app.lyricsLockedAndroid ? '1' : '0',
          );
          expect(tester.takeException(), isNull);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
