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
}
