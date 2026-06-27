import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/scanner/controller/scanner_controller.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/providers/scanner_providers.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/widgets/global_scanner_input.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_router.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_service.dart';

void main() {
  testWidgets(
      'global scanner input claims focus when no other field is focused',
      (tester) async {
    final container = _makeContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildHarness(container));

    container
        .read(scannerControllerProvider.notifier)
        .setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 300));

    expect(_hasFocus(tester, _kScannerKey), isTrue,
        reason: 'Scanner should hold focus when no other field is active');
  });

  testWidgets(
      'global scanner input does NOT steal focus from a user-tapped field',
      (tester) async {
    final container = _makeContainer();
    addTearDown(container.dispose);

    final manualFocusNode = FocusNode();
    addTearDown(manualFocusNode.dispose);

    await tester.pumpWidget(_buildHarness(container, extraFocusNode: manualFocusNode));

    container
        .read(scannerControllerProvider.notifier)
        .setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 300));

    // User explicitly taps the manual input field.
    await tester.tap(find.byKey(const Key('manual-field')));
    await tester.pump();
    expect(_hasFocus(tester, const Key('manual-field')), isTrue,
        reason: 'Manual field should have focus after tap');

    // Wait well past the scanner periodic timer interval (500 ms).
    // The scanner must NOT steal focus from an intentionally-focused field.
    await tester.pump(const Duration(milliseconds: 600));
    expect(_hasFocus(tester, const Key('manual-field')), isTrue,
        reason: 'Scanner must not steal focus from a user-focused field');
  });

  testWidgets(
      'global scanner input reclaims focus after manual field is unfocused',
      (tester) async {
    final container = _makeContainer();
    addTearDown(container.dispose);

    final manualFocusNode = FocusNode();
    addTearDown(manualFocusNode.dispose);

    await tester.pumpWidget(_buildHarness(container, extraFocusNode: manualFocusNode));

    container
        .read(scannerControllerProvider.notifier)
        .setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 300));

    // User taps manual field, then dismisses it.
    await tester.tap(find.byKey(const Key('manual-field')));
    await tester.pump();
    expect(_hasFocus(tester, const Key('manual-field')), isTrue);

    manualFocusNode.unfocus();
    await tester.pump(const Duration(milliseconds: 600));

    expect(_hasFocus(tester, _kScannerKey), isTrue,
        reason: 'Scanner should reclaim focus once manual field is unfocused');
  });
}

// ── helpers ──────────────────────────────────────────────────────────────────

const Key _kScannerKey = Key('global-scanner-input');

ProviderContainer _makeContainer() {
  final handler = _SpyHandler();
  return ProviderContainer(
    overrides: <Override>[
      scannerControllerProvider.overrideWith(
        (ref) => ScannerController(
          scannerService: const ScannerService(),
          modeRouter: ScannerModeRouter(
            salesHandler: handler,
            purchaseHandler: handler,
            inventoryHandler: handler,
          ),
        ),
      ),
    ],
  );
}

Widget _buildHarness(ProviderContainer container, {FocusNode? extraFocusNode}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                key: const Key('manual-field'),
                focusNode: extraFocusNode,
              ),
            ),
            const GlobalScannerInput(),
          ],
        ),
      ),
    ),
  );
}

bool _hasFocus(WidgetTester tester, Key key) {
  final widget = tester.widget<TextField>(find.byKey(key));
  return widget.focusNode?.hasFocus ?? false;
}

class _SpyHandler implements ScannerModeHandler {
  @override
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload) async {
    return const ScannerHandlerResult(
      isSuccess: true,
      code: 'ok',
      message: 'ok',
    );
  }
}
