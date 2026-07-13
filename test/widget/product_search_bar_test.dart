import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/product_search_bar.dart';

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  Widget host({ValueChanged<String>? onChanged}) => MaterialApp(
        home: Scaffold(
          body: ProductSearchBar(
            controller: controller,
            autofocus: false,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );

  testWidgets('renders the search hint and icon', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Search product / SKU / brand'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    // No clear button while the field is empty.
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('reports typed queries through onChanged', (tester) async {
    String? query;
    await tester.pumpWidget(host(onChanged: (value) => query = value));

    await tester.enterText(find.byType(TextField), 'iphone 13');
    expect(query, 'iphone 13');
    expect(controller.text, 'iphone 13');
  });

  testWidgets('clear button empties the field and reports an empty query',
      (tester) async {
    String? query;
    await tester.pumpWidget(host(onChanged: (value) => query = value));

    await tester.enterText(find.byType(TextField), 'galaxy');
    await tester.pump();
    // The clear affordance appears once there is text.
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(query, '');
    expect(find.byIcon(Icons.clear), findsNothing);
  });
}
