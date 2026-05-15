class ReportFilterEntity {
  const ReportFilterEntity({
    this.startDate,
    this.endDate,
    this.customerId,
    this.productModelId,
    this.status,
    this.paymentMethod,
    this.page = 1,
    this.pageSize = 50,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? customerId;
  final String? productModelId;
  final String? status;
  final String? paymentMethod;
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
    int? page,
    int? pageSize,
  }) {
    return ReportFilterEntity(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customerId: clearCustomerId ? null : customerId ?? this.customerId,
      productModelId: clearProductModelId
          ? null
          : productModelId ?? this.productModelId,
      status: clearStatus ? null : status ?? this.status,
      paymentMethod: clearPaymentMethod
          ? null
          : paymentMethod ?? this.paymentMethod,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
