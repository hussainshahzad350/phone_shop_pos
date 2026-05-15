import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

enum InvoicePaperSize {
  thermal58,
  thermal80,
  a4,
}

extension InvoicePaperSizeX on InvoicePaperSize {
  String get label => switch (this) {
    InvoicePaperSize.thermal58 => 'Thermal 58mm',
    InvoicePaperSize.thermal80 => 'Thermal 80mm',
    InvoicePaperSize.a4 => 'A4 Invoice',
  };

  int get charactersPerLine => switch (this) {
    InvoicePaperSize.thermal58 => 28,
    InvoicePaperSize.thermal80 => 40,
    InvoicePaperSize.a4 => 90,
  };
}

class InvoicePrintDocument {
  const InvoicePrintDocument({
    required this.saleId,
    required this.invoiceNumber,
    required this.saleDate,
    required this.items,
    required this.totals,
    required this.paymentMethod,
    this.customerLabel,
    this.notes,
    this.cashierName,
    this.storeName = 'Phone Shop POS',
  });

  final String saleId;
  final String invoiceNumber;
  final DateTime saleDate;
  final List<CartItemEntity> items;
  final SaleTotalsEntity totals;
  final String paymentMethod;
  final String? customerLabel;
  final String? notes;
  final String? cashierName;
  final String storeName;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'saleId': saleId,
      'invoiceNumber': invoiceNumber,
      'saleDate': DateTimeHelpers.toSql(saleDate),
      'items': items.map((item) => <String, Object?>{
        'productModelId': item.productModelId,
        'productName': item.productName,
        'hasImei': item.hasImei,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'serializedStockId': item.serializedStockId,
        'imei': item.imei,
      }).toList(growable: false),
      'totals': <String, Object?>{
        'subtotal': totals.subtotal,
        'discount': totals.discount,
        'tax': totals.tax,
        'total': totals.total,
        'paidAmount': totals.paidAmount,
      },
      'paymentMethod': paymentMethod,
      'customerLabel': customerLabel,
      'notes': notes,
      'cashierName': cashierName,
      'storeName': storeName,
    };
  }

  factory InvoicePrintDocument.fromMap(Map<String, Object?> map) {
    final rawItems = map['items'] as List<Object?>? ?? const <Object?>[];
    final totalsMap = map['totals'] as Map<Object?, Object?>? ?? const <Object?, Object?>{};
    return InvoicePrintDocument(
      saleId: map['saleId'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      saleDate: DateTimeHelpers.fromSql(
        map['saleDate'] as String? ?? DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      ),
      items: rawItems.map((rawItem) {
        final item = rawItem as Map<Object?, Object?>;
        return CartItemEntity(
          productModelId: item['productModelId'] as String? ?? '',
          productName: item['productName'] as String? ?? '',
          hasImei: item['hasImei'] as bool? ?? false,
          quantity: (item['quantity'] as num?)?.toInt() ?? 0,
          unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
          serializedStockId: item['serializedStockId'] as String?,
          imei: item['imei'] as String?,
        );
      }).toList(growable: false),
      totals: SaleTotalsEntity(
        subtotal: (totalsMap['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (totalsMap['discount'] as num?)?.toDouble() ?? 0,
        tax: (totalsMap['tax'] as num?)?.toDouble() ?? 0,
        total: (totalsMap['total'] as num?)?.toDouble() ?? 0,
        paidAmount: (totalsMap['paidAmount'] as num?)?.toDouble() ?? 0,
      ),
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      customerLabel: map['customerLabel'] as String?,
      notes: map['notes'] as String?,
      cashierName: map['cashierName'] as String?,
      storeName: map['storeName'] as String? ?? 'Phone Shop POS',
    );
  }
}

enum InvoicePrintJobStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

extension InvoicePrintJobStatusX on InvoicePrintJobStatus {
  String get value => switch (this) {
    InvoicePrintJobStatus.pending => 'pending',
    InvoicePrintJobStatus.processing => 'processing',
    InvoicePrintJobStatus.completed => 'completed',
    InvoicePrintJobStatus.failed => 'failed',
    InvoicePrintJobStatus.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    InvoicePrintJobStatus.pending => 'Pending',
    InvoicePrintJobStatus.processing => 'Printing',
    InvoicePrintJobStatus.completed => 'Completed',
    InvoicePrintJobStatus.failed => 'Failed',
    InvoicePrintJobStatus.cancelled => 'Cancelled',
  };

  bool get canRetry =>
      this == InvoicePrintJobStatus.pending || this == InvoicePrintJobStatus.failed;

  bool get isTerminal =>
      this == InvoicePrintJobStatus.completed ||
      this == InvoicePrintJobStatus.failed ||
      this == InvoicePrintJobStatus.cancelled;
}

extension InvoicePrintJobStatusParser on InvoicePrintJobStatus {
  static InvoicePrintJobStatus fromValue(String value) {
    return InvoicePrintJobStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InvoicePrintJobStatus.pending,
    );
  }
}

class InvoicePrintJob {
  const InvoicePrintJob({
    required this.id,
    required this.invoiceNumber,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
    this.status = InvoicePrintJobStatus.pending,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String invoiceNumber;
  final InvoicePrintDocument document;
  final DateTime createdAt;
  final DateTime updatedAt;
  final InvoicePrintJobStatus status;
  final int retryCount;
  final String? lastError;

  String get saleId => document.saleId;

  bool get retryLimitReached => retryCount >= 3;

  InvoicePrintJob copyWith({
    DateTime? updatedAt,
    InvoicePrintJobStatus? status,
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
  }) {
    return InvoicePrintJob(
      id: id,
      invoiceNumber: invoiceNumber,
      document: document,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'sale_id': saleId,
      'invoice_number': invoiceNumber,
      'document_json': document.toMap(),
      'status': status.value,
      'retry_count': retryCount,
      'last_error': lastError,
      'created_at': DateTimeHelpers.toSql(createdAt),
      'updated_at': DateTimeHelpers.toSql(updatedAt),
    };
  }

  factory InvoicePrintJob.fromMap(Map<String, Object?> map) {
    return InvoicePrintJob(
      id: map['id'] as String? ?? '',
      invoiceNumber: map['invoice_number'] as String? ?? '',
      document: InvoicePrintDocument.fromMap(
        map['document_json'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
      createdAt: DateTimeHelpers.fromSql(
        map['created_at'] as String? ?? DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      ),
      updatedAt: DateTimeHelpers.fromSql(
        map['updated_at'] as String? ?? DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      ),
      status: InvoicePrintJobStatusParser.fromValue(
        map['status'] as String? ?? InvoicePrintJobStatus.pending.value,
      ),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error'] as String?,
    );
  }
}
