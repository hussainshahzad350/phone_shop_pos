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
  testWidgets('global scanner input restores focus after other field is focused',
      (tester) async {
    final handler = _SpyHandler();
    final container = ProviderContainer(
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
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(key: Key('manual-field')),
                ),
                GlobalScannerInput(),
              ],
            ),
          ),
        ),
      ),
    );

    container.read(scannerControllerProvider.notifier).setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 300));

    expect(_hasFocus(tester, _GlobalScannerHarness.globalField), isTrue);

    await tester.tap(find.byKey(const Key('manual-field')));
    await tester.pump();
    expect(_hasFocus(tester, const Key('manual-field')), isTrue);

    await tester.pump(const Duration(milliseconds: 350));
    expect(_hasFocus(tester, _GlobalScannerHarness.globalField), isTrue);
  });
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

class _GlobalScannerHarness {
  static const Key globalField = Key('global-scanner-input');
}

bool _hasFocus(WidgetTester tester, Key key) {
  final widget = tester.widget<TextField>(find.byKey(key));
  return widget.focusNode?.hasFocus ?? false;
}
