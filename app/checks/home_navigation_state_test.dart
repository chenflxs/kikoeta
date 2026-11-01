import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/main.dart';
import 'package:kikoeta_app/pages/home_page.dart';
import 'package:kikoeta_app/src/rust/frb_generated.dart';
import 'package:kikoeta_app/widgets.dart';

class _Api extends RustLibApi {
  int worksCalls = 0;
  final searchPages = <int>[];

  String works(int page, String prefix) => jsonEncode({
    'works': List.generate(
      20,
      (i) => {
        'source_id': 'RJ${100000 + (page - 1) * 20 + i}',
        'title': '$prefix ${(page - 1) * 20 + i}',
      },
    ),
    'pagination': {'currentPage': page, 'pageSize': 20, 'totalCount': 40},
  });

  @override
  String? crateApiSimpleGetSetting({required String key}) => null;

  @override
  void crateApiSimpleSetSetting({required String key, required String value}) {}

  @override
  Future<String> crateApiKikoeruApiApiGetWorks({
    required String base,
    required int page,
    required int perPage,
    required String order,
    required String sort,
    bool? subtitle,
    String? seed,
  }) async {
    worksCalls++;
    return works(page, 'Home');
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
    searchPages.add(page);
    return works(page, query);
  }

  @override
  Future<String> crateApiKikoeruApiApiGetMyReviews({
    required String base,
    required int page,
    required int perPage,
    required String order,
    required String sort,
    String? filter,
  }) async => '{"works": [], "totalCount": 0}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final api = _Api();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.worksCalls = 0;
    api.searchPages.clear();
  });

  Future<AppState> showShell(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Shell(app: app),
      ),
    );
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> selectTab(WidgetTester tester, int index) async {
    final rail = find.byType(NavigationRail);
    if (rail.evaluate().isNotEmpty) {
      tester.widget<NavigationRail>(rail).onDestinationSelected!(index);
    } else {
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .onTap!(index);
    }
    await tester.pumpAndSettle();
  }

  Finder homeScroll() => find
      .descendant(of: find.byType(HomePage), matching: find.byType(Scrollable))
      .last;

  for (final width in [480.0, 1000.0]) {
    testWidgets(
      'returning home retains search pages and offset at width $width',
      (tester) async {
        final app = await showShell(tester, width);
        await tester.enterText(find.byType(TextField), 'Search');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final position = tester.state<ScrollableState>(homeScroll()).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(api.searchPages, [1, 2]);
        position.jumpTo(500);
        await tester.pumpAndSettle();
        final homeState = tester.state(find.byType(HomePage));
        final inputState = tester.state(find.byType(TextField));
        final worksCalls = api.worksCalls;

        for (final other in [1, 2]) {
          await selectTab(tester, other);
          expect(find.byType(HomeSearchBar), findsNothing);
          await selectTab(tester, 0);
          expect(app.searchQuery, 'Search');
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Search',
          );
          expect(tester.state(find.byType(HomePage)), same(homeState));
          expect(tester.state(find.byType(TextField)), same(inputState));
          expect(
            tester.state<ScrollableState>(homeScroll()).position,
            same(position),
          );
          expect(position.pixels, 500);
          expect(api.searchPages, [1, 2]);
          expect(api.worksCalls, worksCalls);
        }
        // Re-selecting the active home tab still clears search and refreshes.
        await selectTab(tester, 0);
        expect(app.searchQuery, isEmpty);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(api.worksCalls, worksCalls + 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'returning home retains browse offset and draft at width $width',
      (tester) async {
        final app = await showShell(tester, width);
        final position = tester.state<ScrollableState>(homeScroll()).position;
        position.jumpTo(400);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Unsubmitted draft');
        final controller = tester
            .widget<TextField>(find.byType(TextField))
            .controller!;
        controller.selection = const TextSelection.collapsed(offset: 5);
        app.setSearchExpanded(false);
        await tester.pumpAndSettle();
        final worksCalls = api.worksCalls;
        await selectTab(tester, 2);
        await selectTab(tester, 0);
        expect(app.searchQuery, isEmpty);
        expect(controller.text, 'Unsubmitted draft');
        expect(controller.selection.baseOffset, 5);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller,
          same(controller),
        );
        expect(
          tester.state<ScrollableState>(homeScroll()).position,
          same(position),
        );
        expect(position.pixels, 400);
        expect(api.worksCalls, worksCalls);
        expect(api.searchPages, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
