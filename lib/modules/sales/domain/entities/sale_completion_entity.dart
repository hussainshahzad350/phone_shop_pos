import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

class SaleCompletionEntity {
  const SaleCompletionEntity({
    required this.saleId,
    required this.invoiceNumber,
    required this.totals,
  });

  final String saleId;
  final String invoiceNumber;
  final SaleTotalsEntity totals;
}
