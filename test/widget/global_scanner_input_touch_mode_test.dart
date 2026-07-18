import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/interaction_mode_provider.dart';
import 'package:phone_shop_pos/modules/scanner/controller/scanner_controller.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/providers/scanner_providers.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/widgets/global_scanner_input.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_router.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_service.dart';

void main() {
  testWidgets('touch mode: hidden field never requests an IME connection',
      (tester) async {
    final context = _makeContainer();
    addTearDown(context.container.dispose);

    await tester.pumpWidget(_buildHarness(context.container));

    final scanner = tester.widget<TextField>(find.byKey(_kScannerKey));
    expect(scanner.keyboardType, TextInputType.none,
        reason: 'Touch mode must not summon the on-screen keyboard for the '
            'hidden scanner field');
  });

  testWidgets('touch mode: scanner still reclaims focus when idle',
      (tester) async {
    final context = _makeContainer();
    addTearDown(context.container.dispose);

    await tester.pumpWidget(_buildHarness(context.container));

    context.container
        .read(scannerControllerProvider.notifier)
        .setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 600));

    expect(_hasFocus(tester, _kScannerKey), isTrue,
        reason: 'Idle focus reclaim keeps wedge scanners working in touch '
            'mode');
  });

  testWidgets('touch mode: scanner does not steal focus from a tapped field',
      (tester) async {
    final context = _makeContainer();
    addTearDown(context.container.dispose);

    final manualFocusNode = FocusNode();
    addTearDown(manualFocusNode.dispose);

    await tester.pumpWidget(
      _buildHarness(context.container, extraFocusNode: manualFocusNode),
    );

    context.container
        .read(scannerControllerProvider.notifier)
        .setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('manual-field')));
    await tester.pump();
    expect(_hasFocus(tester, const Key('manual-field')), isTrue);

    // Well past the 500ms reclaim timer: the manual field must keep focus so
    // the operator can type with the on-screen keyboard.
    await tester.pump(const Duration(milliseconds: 600));
    expect(_hasFocus(tester, const Key('manual-field')), isTrue,
        reason: 'Touch mode must not fight the operator for focus');
  });

  testWidgets('touch mode: a submitted scan still reaches the mode handler',
      (tester) async {
    final context = _makeContainer();
    addTearDown(context.container.dispose);

    await tester.pumpWidget(_buildHarness(context.container));

    context.container
        .read(scannerControllerProvider.notifier)
        .setActiveMode(ScannerMode.sales);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_hasFocus(tester, _kScannerKey), isTrue);

    // Wedge scanners type into the focused hidden field and send Enter.
    // Drive the controller through the widget's submit path.
    final scanner = tester.widget<TextField>(find.byKey(_kScannerKey));
    scanner.onSubmitted!.call('356938035643809');
    await tester.pump();
    await tester.pump();

    expect(context.handler.scans, hasLength(1));
    expect(context.handler.scans.single.normalizedValue, '356938035643809');
  });
}

// ── helpers ──────────────────────────────────────────────────────────────────

const Key _kScannerKey = Key('global-scanner-input');

class _TestContext {
  const _TestContext({required this.container, required this.handler});

  final ProviderContainer container;
  final _SpyHandler handler;
}

_TestContext _makeContainer() {
  final handler = _SpyHandler();
  final container = ProviderContainer(
    overrides: <Override>[
      isTouchModeProvider.overrideWithValue(true),
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
  return _TestContext(container: container, handler: handler);
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
  _SpyHandler();

  final List<ScannerScanPayload> scans = <ScannerScanPayload>[];

  @override
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload) async {
    scans.add(payload);
    return const ScannerHandlerResult(
      isSuccess: true,
      code: 'ok',
      message: 'ok',
    );
  }
}
