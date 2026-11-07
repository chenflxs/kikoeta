import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/app_language.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/pages/settings_page.dart';
import 'package:kikoeta_app/sheets.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';
import 'package:kikoeta_app/theme.dart';

void main() {
  final api = _HealthApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    AppLanguage.setPreference('zh-CN');
  });
  tearDown(() => AppLanguage.setPreference(AppLanguage.system));

  Future<AppState> showSettings(WidgetTester tester) async {
    api.response = Completer<String>();
    final app = AppState(languageSettingsWriter: (_, _) {});
    addTearDown(app.dispose);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: app,
        builder: (_, _) => MaterialApp(
          locale: AppLanguage.localeOverride,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(Brightness.light),
          home: SettingsPage(app: app, sectionKey: 'account'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('检测'));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('saves a public custom site without credentials or key', (
    tester,
  ) async {
    final app = AppState(languageSettingsWriter: (_, _) {});
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLanguage.localeOverride,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSiteSheet(context, app),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Public library');
    await tester.enterText(fields.at(1), 'http://127.0.0.1:8888/');
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(app.customSites, hasLength(1));
    final site = app.customSites.single;
    expect(site.url, 'http://127.0.0.1:8888');
    expect(site.user, isEmpty);
    expect(site.pass, isEmpty);
    expect(site.lyricsWritebackKey, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful Chinese checks stay green and relabel in English', (
    tester,
  ) async {
    final app = await showSettings(tester);
    expect(find.text('检测中…'), findsOneWidget);
    api.response.complete('正常 · 277ms');
    await tester.pumpAndSettle();
    final chinese = find.textContaining('正常 · ');
    expect(chinese, findsOneWidget);
    expect(tester.widget<Text>(chinese).style!.color, AppColors.light.green);
    app.setUiLanguage('en');
    await tester.pumpAndSettle();
    final english = find.textContaining('OK · ');
    expect(english, findsOneWidget);
    expect(tester.widget<Text>(english).style!.color, AppColors.light.green);
    app.setUiLanguage('zh-TW');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.textContaining('正常 · ')).style!.color,
      AppColors.light.green,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'checks completing after a locale switch use the current language',
    (tester) async {
      final app = await showSettings(tester);
      app.setUiLanguage('en');
      await tester.pumpAndSettle();
      final waiting = find.text('Checking…');
      expect(waiting, findsOneWidget);
      expect(tester.widget<Text>(waiting).style!.color, AppColors.light.muted);
      api.response.complete('正常 · 1ms');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.textContaining('OK · ')).style!.color,
        AppColors.light.green,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed checks stay red and relabel when switching languages', (
    tester,
  ) async {
    final app = await showSettings(tester);
    api.response.completeError(StateError('unreachable'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('连接失败')).style!.color,
      AppColors.light.red,
    );
    app.setUiLanguage('en');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Connection failed')).style!.color,
      AppColors.light.red,
    );
    expect(tester.takeException(), isNull);
  });
}

class _HealthApi extends RustLibApi {
  late Completer<String> response;

  @override
  Future<String> crateApiKikoeruApiApiHealth({required String base}) =>
      response.future;

  @override
  String? crateApiSimpleGetSetting({required String key}) => null;

  @override
  String? crateApiSimpleGetToken({required String base}) => null;

  @override
  void crateApiSimpleSetSetting({required String key, required String value}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
