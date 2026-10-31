import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/services/api_service.dart';
import 'package:kikoeta_app/sheets.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';
import 'package:kikoeta_app/widgets.dart';

class _App extends AppState {
  _App() : super(languageSettingsWriter: (_, _) {});

  final applied = <int>[];

  @override
  void applyServer(bool custom, int idx) => applied.add(idx);
}

class _Api extends RustLibApi {
  late Completer<String> login;
  int loginCalls = 0;
  String? customQuery;
  String? oneQuery;

  @override
  Future<String> crateApiKikoeruApiApiLogin({
    required String base,
    required String name,
    required String password,
  }) {
    loginCalls++;
    return login.future;
  }

  @override
  Future<String> crateApiKikoeruApiApiSearchCustom({
    required String base,
    required String keyword,
    required int page,
    required String order,
    required String sort,
    int? nsfw,
    String? seed,
  }) async {
    customQuery = keyword;
    return '{"works": [], "totalCount": 0}';
  }

  @override
  Future<String> crateApiKikoeruApiApiSearch({
    required String base,
    required String query,
    required int page,
    required int perPage,
    required String order,
    required String sort,
    bool? subtitle,
    String? seed,
  }) async {
    oneQuery = query;
    return '{"works": [], "totalCount": 0}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final api = _Api();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.loginCalls = 0;
    api.customQuery = null;
    api.oneQuery = null;
  });

  Future<_App> openSheet(WidgetTester tester) async {
    api.login = Completer<String>();
    final app = _App();
    addTearDown(app.dispose);
    app.customServer = true;
    app.customSites.addAll([
      CustomSite(alias: 'Site A', url: 'https://a.test', user: 'u', pass: 'p'),
      CustomSite(alias: 'Site B', url: 'https://b.test', user: 'u', pass: 'p'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showServerSheet(context, app),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return app;
  }

  for (final finishDismissal in [false, true]) {
    testWidgets(
      'dismissed login cannot apply a server (settled: $finishDismissal)',
      (tester) async {
        final app = await openSheet(tester);
        await tester.tap(find.text('Apply'));
        await tester.pump();
        Navigator.of(tester.element(find.text('Apply'))).pop();
        if (finishDismissal) await tester.pumpAndSettle();
        api.login.complete('{}');
        await tester.pumpAndSettle();
        expect(app.applied, isEmpty);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('applying logs in once and freezes the selected server', (
    tester,
  ) async {
    final app = await openSheet(tester);
    final apply = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Apply'))
        .onPressed!;
    apply();
    apply();
    await tester.pump();
    expect(api.loginCalls, 1);
    expect(
      ModalRoute.of(tester.element(find.text('Apply')))!.isCurrent,
      isTrue,
    );
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Apply'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Site B'), warnIfMissed: false);
    expect(
      ModalRoute.of(tester.element(find.text('Apply')))!.isCurrent,
      isTrue,
    );
    await tester.tap(find.byType(Pill).first, warnIfMissed: false);
    expect(
      ModalRoute.of(tester.element(find.text('Apply')))!.isCurrent,
      isTrue,
    );
    api.login.complete('{}');
    await tester.pumpAndSettle();
    expect(app.applied, [0]);
    expect(find.text('Apply'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'custom search automatically combines keywords; ONE keeps its search path',
    () async {
      final app = _App();
      addTearDown(app.dispose);
      app.customServer = true;
      app.customSites.add(
        CustomSite(alias: 'Site', url: 'https://custom.test'),
      );
      for (final query in ['雨 夜', '雨,夜', '雨，夜']) {
        await ApiService.searchWorks(app, query);
        expect(jsonDecode(api.customQuery!), [
          {'t': 1, 'd': '雨'},
          {'t': 1, 'd': '夜'},
        ]);
      }
      await ApiService.searchWorks(app, '雨');
      expect(api.customQuery, '雨');
      app.customServer = false;
      api.customQuery = null;
      await ApiService.searchWorks(app, '雨 夜');
      expect(api.customQuery, isNull);
      expect(api.oneQuery, contains('雨 夜'));
    },
  );

  test(
    'a complete REST playlist stops pagination even at an exact page boundary',
    () {
      for (final count in [0, 20, 1000]) {
        final page = ApiService.parseWorks(
          jsonEncode({
            'works': List.generate(
              count,
              (i) => {'id': i + 1, 'title': 'Work $i'},
            ),
            'pagination': {
              'currentPage': 1,
              'pageSize': count == 0 ? 1 : count,
              'totalCount': count,
            },
          }),
        );
        expect(page.works.length, count);
        expect(page.totalCount, count);
        expect(page.hasMore, isFalse);
      }
    },
  );
}
