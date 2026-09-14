import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/widgets.dart';

void main() {
  testWidgets('clearing a submitted search hides the clear button', (
    tester,
  ) async {
    final app = AppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 480, child: HomeSearchBar(app: app)),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'RJ123456');
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(app.pendingClear, isTrue);
  });

  testWidgets(
    'focused search shows advanced search guide and inserts dollar sign',
    (tester) async {
      final app = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 480, child: HomeSearchBar(app: app)),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('advanced-search-guide')), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('advanced-search-guide')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('advanced-search-guide')));
      await tester.pump();
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, r'$');
      expect(textField.focusNode!.hasFocus, isTrue);
      expect(app.searchExpanded, isTrue);
    },
  );
}
