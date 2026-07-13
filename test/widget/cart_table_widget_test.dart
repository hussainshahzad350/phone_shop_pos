import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/cart_table_widget.dart';

void main() {
  // The cart row is a desktop-width layout; use a wide surface so its Row does
  // not report a horizontal overflow during tests.
  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  CartItemEntity accessory({int quantity = 2, double unitPrice = 500}) =>
      CartItemEntity(
        productModelId: 'p1',
        productName: 'Charger',
        hasImei: false,
        quantity: quantity,
        unitPrice: unitPrice,
      );

  Widget host({
    required List<CartItemEntity> items,
    ValueChanged<int>? onIncreaseQty,
    ValueChanged<int>? onDecreaseQty,
    ValueChanged<int>? onRemove,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: CartTableWidget(
            items: items,
            onIncreaseQty: onIncreaseQty ?? (_) {},
            onDecreaseQty: onDecreaseQty ?? (_) {},
            onUpdateUnitPrice: (_, __) {},
            onRemove: onRemove ?? (_) {},
          ),
        ),
      );

  testWidgets('shows a placeholder when the cart is empty', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(host(items: const <CartItemEntity>[]));

    expect(find.text('Cart is empty'), findsOneWidget);
  });

  testWidgets('renders a quantity item with its stepper and remove control',
      (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(host(items: <CartItemEntity>[accessory()]));

    expect(find.text('Charger'), findsOneWidget);
    expect(find.text('Quantity-based'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // quantity
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    expect(find.byTooltip('Remove item'), findsOneWidget);
  });

  testWidgets('stepper and remove buttons fire callbacks with the row index',
      (tester) async {
    int? increased;
    int? decreased;
    int? removed;
    useWideSurface(tester);
    await tester.pumpWidget(host(
      items: <CartItemEntity>[accessory()],
      onIncreaseQty: (i) => increased = i,
      onDecreaseQty: (i) => decreased = i,
      onRemove: (i) => removed = i,
    ));

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    expect(increased, 0);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    expect(decreased, 0);

    await tester.tap(find.byTooltip('Remove item'));
    expect(removed, 0);
  });

  testWidgets('serialized item shows the IMEI label and no quantity stepper',
      (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(host(
      items: <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'p2',
          productName: 'iPhone 13',
          hasImei: true,
          quantity: 1,
          unitPrice: 80000,
          imei: '123456789012345',
        ),
      ],
    ));

    expect(find.text('Serialized (IMEI)'), findsOneWidget);
    expect(find.textContaining('123456789012345'), findsOneWidget);
    // Serialized rows are single-unit: no increment/decrement stepper.
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
  });
}
