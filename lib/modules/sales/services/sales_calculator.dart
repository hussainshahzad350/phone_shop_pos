import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

class SalesCalculator {
  const SalesCalculator();

  SaleTotalsEntity calculate({
    required List<CartItemEntity> items,
    required double discount,
    required double tax,
    required double paidAmount,
  }) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);

    final sanitizedDiscount = discount.clamp(0, subtotal).toDouble();
    final sanitizedTax = tax < 0 ? 0.0 : tax;
    final total = (subtotal - sanitizedDiscount) + sanitizedTax;
    final sanitizedPaidAmount = paidAmount.clamp(0.0, total);

    return SaleTotalsEntity(
      subtotal: subtotal,
      discount: sanitizedDiscount,
      tax: sanitizedTax,
      total: total,
      paidAmount: sanitizedPaidAmount,
    );
  }
}
