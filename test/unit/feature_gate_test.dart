import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';
import 'package:phone_shop_pos/core/config/feature_gate.dart';

void main() {
  group('FeatureGate widget', () {
    testWidgets('renders child when condition is met', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            featureFlagsProvider.overrideWith((ref) async {
              return const FeatureFlags.currentBehaviorDefaults().copyWith(
                repairModule: true,
              );
            }),
          ],
          child: MaterialApp(
            home: FeatureGate(
              condition: (flags) => flags.repairModule,
              fallback: const Text('Fallback'),
              child: const Text('Child'),
            ),
          ),
        ),
      );

      // wait for provider to resolve
      await tester.pumpAndSettle();

      expect(find.text('Child'), findsOneWidget);
      expect(find.text('Fallback'), findsNothing);
    });

    testWidgets('renders fallback when condition is not met', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            featureFlagsProvider.overrideWith((ref) async {
              return const FeatureFlags.currentBehaviorDefaults().copyWith(
                repairModule: false,
              );
            }),
          ],
          child: MaterialApp(
            home: FeatureGate(
              condition: (flags) => flags.repairModule,
              fallback: const Text('Fallback'),
              child: const Text('Child'),
            ),
          ),
        ),
      );

      // wait for provider to resolve
      await tester.pumpAndSettle();

      expect(find.text('Fallback'), findsOneWidget);
      expect(find.text('Child'), findsNothing);
    });

    testWidgets('preserves default behavior while loading', (tester) async {
      final completer = Completer<FeatureFlags>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            featureFlagsProvider.overrideWith((ref) async {
              // Return a future that doesn't resolve immediately
              return completer.future;
            }),
          ],
          child: MaterialApp(
            home: FeatureGate(
              // imeiStock defaults to true, so Child should show while loading
              condition: (flags) => flags.imeiStock,
              fallback: const Text('Fallback'),
              child: const Text('Child'),
            ),
          ),
        ),
      );

      // In loading state, uses currentBehaviorDefaults — imeiStock=true → Child
      expect(find.text('Child'), findsOneWidget);

      completer.complete(const FeatureFlags.currentBehaviorDefaults());
      await tester.pumpAndSettle();
    });
  });
}
