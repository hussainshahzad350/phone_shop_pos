import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/sales/data/models/sale_item_model.dart';

void main() {
  group('SaleItemModel.fromMap', () {
    test('parses SQLite numeric rows with mixed num types', () {
      final model = SaleItemModel.fromMap(<String, Object?>{
        'id': 'sli-1',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'sale_id': 'sale-1',
        'product_model_id': 'product-1',
        'serialized_stock_id': 'ss-1',
        'quantity': 2,
        'unit_price': 1500.5,
        'discount': 10,
        'line_total': 2991.0,
        'cost_price': 1200,
      });

      expect(model.id, 'sli-1');
      expect(model.saleId, 'sale-1');
      expect(model.productModelId, 'product-1');
      expect(model.serializedStockId, 'ss-1');
      expect(model.quantity, 2);
      expect(model.unitPrice, 1500.5);
      expect(model.discount, 10);
      expect(model.lineTotal, 2991.0);
      expect(model.costPrice, 1200.0);
      expect(
        DateTimeHelpers.toSql(model.createdAt),
        '2026-01-01T00:00:00.000Z',
      );
    });

    test('handles null/string numeric values with safe fallbacks', () {
      final model = SaleItemModel.fromMap(<String, Object?>{
        'id': 'sli-2',
        'created_at': '2026-02-01T00:00:00.000Z',
        'updated_at': '2026-02-01T00:00:00.000Z',
        'sale_id': 'sale-2',
        'product_model_id': 'product-2',
        'serialized_stock_id': null,
        'quantity': '3',
        'unit_price': '2000.25',
        'discount': null,
        'line_total': '6000.75',
        'cost_price': null,
      });

      expect(model.serializedStockId, isNull);
      expect(model.quantity, 3);
      expect(model.unitPrice, 2000.25);
      expect(model.discount, 0);
      expect(model.lineTotal, 6000.75);
      expect(model.costPrice, 0);
    });
  });
}
