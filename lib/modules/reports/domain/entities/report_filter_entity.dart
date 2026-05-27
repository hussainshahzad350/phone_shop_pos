/// [itemType] can be `'phones'`, `'accessories'`, or `null` (all items).
class ReportFilterEntity {
  const ReportFilterEntity({
    this.startDate,
    this.endDate,
    this.customerId,
    this.productModelId,
    this.status,
    this.paymentMethod,
    this.itemType,
    this.page = 1,
    this.pageSize = 50,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? customerId;
  final String? productModelId;
  final String? status;
  final String? paymentMethod;

  /// `'phones'`, `'accessories'`, or `null` (all)
  final String? itemType;

  final int page;
  final int pageSize;

  int get offset => (page - 1) * pageSize;

  ReportFilterEntity copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    bool clearCustomerId = false,
    String? productModelId,
    bool clearProductModelId = false,
    String? status,
    bool clearStatus = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    String? itemType,
    bool clearItemType = false,
    int? page,
    int? pageSize,
  }) {
    return ReportFilterEntity(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customerId: clearCustomerId ? null : customerId ?? this.customerId,
      productModelId:
          clearProductModelId ? null : productModelId ?? this.productModelId,
      status: clearStatus ? null : status ?? this.status,
      paymentMethod:
          clearPaymentMethod ? null : paymentMethod ?? this.paymentMethod,
      itemType: clearItemType ? null : itemType ?? this.itemType,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
