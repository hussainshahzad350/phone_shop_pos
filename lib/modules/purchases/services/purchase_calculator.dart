import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';

class PurchaseCalculator {
  const PurchaseCalculator();

  ({double subtotal, double total}) calculate({
    required List<PurchaseFormItem> items,
    required double discount,
    required double tax,
  }) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final sanitizedDiscount = discount.clamp(0, subtotal);
    final sanitizedTax = tax < 0 ? 0 : tax;
    final total = (subtotal - sanitizedDiscount) + sanitizedTax;
    return (subtotal: subtotal, total: total);
  }
}
