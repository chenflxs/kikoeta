import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scaled UI still receives gestures when reduced', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_scaledTapSurface(scale: .75, onTap: () => taps++));

    await tester.tapAt(const Offset(150, 300));
    expect(taps, 1);
  });

  testWidgets('scaled UI still receives gestures when enlarged', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_scaledTapSurface(scale: 2, onTap: () => taps++));

    await tester.tapAt(const Offset(225, 450));
    expect(taps, 1);
  });
}

Widget _scaledTapSurface({required double scale, required VoidCallback onTap}) {
  const viewport = Size(300, 600);
  final virtualSize = Size(viewport.width / scale, viewport.height / scale);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: virtualSize.width,
          height: virtualSize.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ),
  );
}
