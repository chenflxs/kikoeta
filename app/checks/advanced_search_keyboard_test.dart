import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/l10n/generated/app_localizations.dart';
import 'package:kikoeta_app/pages/downloads_page.dart';
import 'package:kikoeta_app/services/download_service.dart';
import 'package:kikoeta_app/theme.dart';
import 'package:kikoeta_app/widgets.dart';

class _SearchAppState extends AppState {
  @override
  void addHistory(String query) {
    // 搜索交互测试使用内存历史，不初始化 Rust 设置数据库。
    history.add(query);
    notify();
  }
}

void main() {
  const searchPaintKey = ValueKey('search-paint');

  Future<AppState> showHome(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final app = _SearchAppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(brightness),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: app,
            builder: (_, _) => Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: searchPaintKey,
                child: HomeSearchBar(app: app),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    return app;
  }

  TextEditingController controller(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('highlight background visibly moves in $brightness', (
      tester,
    ) async {
      await showHome(tester, brightness: brightness);
      await tester.enterText(find.byType(TextField), r'$');
      await tester.pumpAndSettle();

      Future<List<int>> backgroundPixel(String token) async {
        final row = find.ancestor(
          of: find.text(token),
          matching: find.byType(InkWell),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(searchPaintKey),
        );
        // 参数名与说明之间的空白处，直接验证最终绘制的背景像素。
        final point = boundary.globalToLocal(
          tester.getTopLeft(row) + Offset(100, tester.getSize(row).height / 2),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return bytes!.buffer.asUint8List(offset, 4).toList();
          } finally {
            image.dispose();
          }
        }))!;
      }

      final firstSelected = await backgroundPixel(r'$tag:');
      final secondUnselected = await backgroundPixel(r'$tagw:');
      expect(firstSelected, isNot(equals(secondUnselected)));
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(await backgroundPixel(r'$tag:'), equals(secondUnselected));
      expect(await backgroundPixel(r'$tagw:'), equals(firstSelected));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('arrows highlight options and Enter completes before searching', (
    tester,
  ) async {
    final app = await showHome(tester);
    await tester.enterText(find.byType(TextField), r'$');
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.enter);
    expect(controller(tester).text, r'$tagw:');
    expect(app.searchQuery, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.byType(AdvancedSearchSuggestions), findsNothing);
    await tester.enterText(find.byType(TextField), r'$tagw:耳かき');
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.enter);
    // 未被菜单消费的 Enter 由平台文本输入通道提交。
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(app.searchQuery, r'$tagw:耳かき');
    expect(app.searchExpanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard selection scrolls to the last option and clamps there',
    (tester) async {
      await showHome(tester);
      await tester.enterText(find.byType(TextField), r'$');
      await tester.pumpAndSettle();
      for (var i = 0; i < advancedSearchParameters.length + 2; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(find.text(r'$-lang:').hitTestable(), findsOneWidget);
      final selected = find.ancestor(
        of: find.text(r'$-lang:'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      );
      expect(selected, findsOneWidget);
      await press(tester, LogicalKeyboardKey.numpadEnter);
      expect(controller(tester).text, r'$-lang:');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filtering resets selection and preserves text after the cursor',
    (tester) async {
      await showHome(tester);
      await tester.enterText(find.byType(TextField), r'hello $ world');
      controller(tester).selection = const TextSelection.collapsed(offset: 7);
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      controller(tester).value = const TextEditingValue(
        text: r'hello $va world',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.enter);
      expect(controller(tester).text, r'hello $va: world');
      expect(controller(tester).selection.baseOffset, 10);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Escape dismisses suggestions and ordinary Enter still searches',
    (tester) async {
      final app = await showHome(tester);
      await tester.enterText(find.byType(TextField), r'$');
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(AdvancedSearchSuggestions), findsNothing);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.searchQuery, r'$');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mouse completion keeps focus and IME composition hides options',
    (tester) async {
      await showHome(tester);
      await tester.enterText(find.byType(TextField), r'$');
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'$circle:'));
      await tester.pumpAndSettle();
      expect(controller(tester).text, r'$circle:');
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      controller(tester).value = const TextEditingValue(
        text: r'$va',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 1, end: 3),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdvancedSearchSuggestions), findsNothing);
      controller(tester).value = controller(
        tester,
      ).value.copyWith(composing: TextRange.empty);
      await tester.pumpAndSettle();
      expect(find.text(r'$va:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('download search uses the same keyboard completion', (
    tester,
  ) async {
    final app = AppState();
    // ignore: invalid_use_of_visible_for_testing_member
    final manager = DownloadManager.forTesting(
      voiceRoot: 'unused',
      writeSetting: (_, _) {},
    );
    addTearDown(app.dispose);
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(Brightness.light),
        home: DownloadPage(app: app, manager: manager),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), r'$');
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);
    expect(controller(tester).text, r'$tagw:');
    expect(find.byType(AdvancedSearchSuggestions), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
