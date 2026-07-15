import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/theme/app_interaction_tokens.dart';
import 'package:phone_shop_pos/core/theme/app_theme.dart';

void main() {
  group('AppTheme desktop profile (touch off)', () {
    // Pins today's desktop density values: Touch mode must be strictly
    // additive, so these knobs regressing would change every screen.
    test('keeps the compact desktop density knobs', () {
      final theme = AppTheme.light();

      expect(theme.visualDensity, VisualDensity.compact);
      expect(theme.inputDecorationTheme.isDense, isTrue);
      expect(theme.dataTableTheme.dataRowMinHeight, 40);

      final tokens = theme.extension<AppInteractionTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.isTouch, isFalse);
      expect(tokens.rowActionIconSize, 18);
      expect(tokens.controlDensity, VisualDensity.compact);
      expect(tokens.minButtonSize, Size.zero);
      expect(tokens.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('buttons keep their previous vertical padding', () {
      final theme = AppTheme.light();
      final padding = theme.filledButtonTheme.style?.padding
          ?.resolve(const <WidgetState>{}) as EdgeInsets?;
      expect(padding?.top, 12);
      expect(padding?.bottom, 12);
    });
  });

  group('AppTheme touch profile', () {
    test('inflates density, inputs and table rows', () {
      final theme = AppTheme.light(touch: true);

      expect(theme.visualDensity, VisualDensity.standard);
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(theme.inputDecorationTheme.isDense, isFalse);
      expect(theme.dataTableTheme.dataRowMinHeight, 48);
      expect(theme.dataTableTheme.dataRowMaxHeight, 64);
      expect(
        theme.dataTableTheme.dataRowMinHeight! <=
            theme.dataTableTheme.dataRowMaxHeight!,
        isTrue,
      );

      final tokens = theme.extension<AppInteractionTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.isTouch, isTrue);
      expect(tokens.rowActionIconSize, 22);
      expect(tokens.controlDensity, VisualDensity.standard);
      expect(tokens.minButtonSize, const Size(48, 48));
      expect(tokens.tapTargetSize, MaterialTapTargetSize.padded);
      expect(tokens.dataRowMinHeight, 48);
      expect(tokens.dataRowMaxHeight, 64);
    });

    test('applies to the dark theme too', () {
      final theme = AppTheme.dark(touch: true);
      expect(theme.visualDensity, VisualDensity.standard);
      expect(theme.extension<AppInteractionTokens>()?.isTouch, isTrue);
    });
  });

  group('AppInteractionTokens.of', () {
    testWidgets('falls back to desktop under a bare MaterialApp',
        (tester) async {
      late AppInteractionTokens tokens;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              tokens = AppInteractionTokens.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tokens.isTouch, isFalse);
      expect(tokens.rowActionIconSize, 18);
    });
  });
}
