import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/imei_picker_dialog.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';

void main() {
  group('PHASE 1 / SECTION E-F (S-026 ... S-030)', () {
    testWidgets('S-026 Keyboard navigation', (tester) async {
      final selected = await _openDialogAndSendKeys(
        tester: tester,
        keys: const <LogicalKeyboardKey>[
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.enter,
        ],
      );
      expect(selected?.id, 'ss-1');

      final cancelled = await _openDialogAndSendKeys(
        tester: tester,
        keys: const <LogicalKeyboardKey>[LogicalKeyboardKey.escape],
      );
      expect(cancelled, isNull);
    });

    testWidgets('S-027 Keyboard-only sale', (tester) async {
      var completeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentSectionWidget(
              paymentMethod: 'cash',
              paidAmount: 0,
              notes: '',
              onPaymentMethodChanged: (_) {},
              onPaidAmountChanged: (_) {},
              onNotesChanged: (_) {},
              onCompleteSale: () {
                completeCount += 1;
              },
              isProcessing: false,
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextField, 'Paid Amount'));
      await tester.enterText(
          find.widgetWithText(TextField, 'Paid Amount'), '2500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(completeCount, 1);
    });

    testWidgets('S-028 Enter key on paid amount', (tester) async {
      var submittedCount = 0;
      var completeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentSectionWidget(
              paymentMethod: 'cash',
              paidAmount: 0,
              notes: '',
              onPaymentMethodChanged: (_) {},
              onPaidAmountChanged: (_) {},
              onNotesChanged: (_) {},
              onPaidAmountSubmitted: () {
                submittedCount += 1;
              },
              onCompleteSale: () {
                completeCount += 1;
              },
              isProcessing: false,
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextField, 'Paid Amount'));
      await tester.enterText(
          find.widgetWithText(TextField, 'Paid Amount'), '1000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submittedCount, 1);
      expect(completeCount, 0);
    });

    testWidgets('S-029 Focus restore after interruption', (tester) async {
      final launcherFocus = FocusNode();
      addTearDown(launcherFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  focusNode: launcherFocus,
                  onPressed: () async {
                    await showDialog<SerializedStockEntity>(
                      context: context,
                      builder: (_) => ImeiPickerDialog(
                        productName: 'Phone Focus',
                        productModelId: 'pm-focus',
                        repository: _DialogSalesRepository(),
                      ),
                    );
                  },
                  child: const Text('Open IMEI Dialog'),
                );
              },
            ),
          ),
        ),
      );

      launcherFocus.requestFocus();
      await tester.pump();
      expect(launcherFocus.hasFocus, isTrue);

      await tester.tap(find.text('Open IMEI Dialog'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(launcherFocus.hasFocus, isTrue);
    });

    testWidgets('S-030 Rapid double-click save', (tester) async {
      var completeCount = 0;
      var isProcessing = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PaymentSectionWidget(
                  paymentMethod: 'cash',
                  paidAmount: 500,
                  notes: '',
                  onPaymentMethodChanged: (_) {},
                  onPaidAmountChanged: (_) {},
                  onNotesChanged: (_) {},
                  onCompleteSale: () {
                    if (isProcessing) {
                      return;
                    }
                    completeCount += 1;
                    setState(() {
                      isProcessing = true;
                    });
                  },
                  isProcessing: isProcessing,
                );
              },
            ),
          ),
        ),
      );

      final buttonFinder = find.text('Complete Sale (F10)');
      await tester.tap(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(completeCount, 1);
    });
  });
}

Future<SerializedStockEntity?> _openDialogAndSendKeys({
  required WidgetTester tester,
  required List<LogicalKeyboardKey> keys,
}) async {
  final repository = _DialogSalesRepository();
  SerializedStockEntity? selected;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showDialog<SerializedStockEntity>(
                    context: context,
                    builder: (_) => ImeiPickerDialog(
                      productName: 'Phone A',
                      productModelId: 'pm-1',
                      repository: repository,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  for (final key in keys) {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  await tester.pumpAndSettle();
  return selected;
}

class _DialogSalesRepository implements SalesRepository {
  @override
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) async {
    return const Failure<SaleCompletionEntity>(
      AppError(code: 'not_implemented', message: 'Not needed for this test'),
    );
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    final all = <SerializedStockEntity>[
      _dialogStock(id: 'ss-1', imei1: '111111111111111'),
      _dialogStock(id: 'ss-2', imei1: '222222222222222'),
    ];
    return Success<List<SerializedStockEntity>>(all);
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) async {
    return const Success<int>(0);
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  }) async {
    return const Success<List<CustomerOptionEntity>>(<CustomerOptionEntity>[]);
  }

  @override
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  }) async {
    return const Success<List<ProductEntity>>(<ProductEntity>[]);
  }

  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) async {
    try {
      final value = await action();
      return Success<T>(value);
    } catch (error) {
      return Failure<T>(
        AppError(
          code: 'dialog_repo_error',
          message: 'Dialog repository failed during $operation',
          details: error,
        ),
      );
    }
  }
}

SerializedStockEntity _dialogStock({
  required String id,
  required String imei1,
}) {
  return SerializedStockEntity(
    id: id,
    productModelId: 'pm-1',
    imei1: imei1,
    stockStatus: SerializedStockStatus.inStock,
    costPrice: 1000,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}
