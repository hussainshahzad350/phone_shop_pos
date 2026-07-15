import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

void main() {
  const childKey = Key('dialog-content');

  Widget harness({required Size screen, required Widget child}) {
    return MediaQuery(
      data: MediaQueryData(size: screen),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );
  }

  group('AppDialogContentBox', () {
    testWidgets('keeps the design width on the desktop minimum window',
        (tester) async {
      await tester.pumpWidget(
        harness(
          screen: const Size(1366, 768),
          child: const AppDialogContentBox(
            width: 980,
            child: SizedBox(key: childKey, height: 10),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(childKey)).width, 980);
    });

    testWidgets('clamps a 980-wide dialog on a narrow screen', (tester) async {
      await tester.pumpWidget(
        harness(
          screen: const Size(800, 600),
          child: const AppDialogContentBox(
            width: 980,
            child: SizedBox(key: childKey, height: 10),
          ),
        ),
      );

      // 800 screen - 128 dialog chrome = 672 usable width.
      expect(tester.getSize(find.byKey(childKey)).width, 672);
    });

    testWidgets('clamps a fixed content height on short screens',
        (tester) async {
      await tester.pumpWidget(
        harness(
          screen: const Size(800, 600),
          child: const AppDialogContentBox(
            width: 700,
            height: 560,
            child: SizedBox.expand(key: childKey),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(childKey));
      expect(size.width, 672);
      // 600 screen - 160 vertical chrome = 440 usable height.
      expect(size.height, 440);
    });

    testWidgets('never collapses below the minimum width', (tester) async {
      await tester.pumpWidget(
        harness(
          screen: const Size(300, 400),
          child: const AppDialogContentBox(
            width: 980,
            child: SizedBox(key: childKey, height: 10),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(childKey)).width, 280);
    });
  });
}
