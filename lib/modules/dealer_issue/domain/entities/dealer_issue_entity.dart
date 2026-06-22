class DealerIssueEntity {
  final String issueId;
  final String dealerId;
  final List<String> imeiList;
  final DateTime issueDate;
  final bool returnStatus;
  final DateTime? returnedAt;
  final bool convertedToSale;
  final String? saleInvoiceId;
  final bool soldStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DealerIssueEntity({
    required this.issueId,
    required this.dealerId,
    required this.imeiList,
    required this.issueDate,
    this.returnStatus = false,
    this.returnedAt,
    this.convertedToSale = false,
    this.saleInvoiceId,
    this.soldStatus = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  DealerIssueEntity copyWith({
    String? issueId,
    String? dealerId,
    List<String>? imeiList,
    DateTime? issueDate,
    bool? returnStatus,
    DateTime? returnedAt,
    bool? convertedToSale,
    String? saleInvoiceId,
    bool? soldStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DealerIssueEntity(
      issueId: issueId ?? this.issueId,
      dealerId: dealerId ?? this.dealerId,
      imeiList: imeiList ?? this.imeiList,
      issueDate: issueDate ?? this.issueDate,
      returnStatus: returnStatus ?? this.returnStatus,
      returnedAt: returnedAt ?? this.returnedAt,
      convertedToSale: convertedToSale ?? this.convertedToSale,
      saleInvoiceId: saleInvoiceId ?? this.saleInvoiceId,
      soldStatus: soldStatus ?? this.soldStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'issue_id': issueId,
      'dealer_id': dealerId,
      'imei_list': imeiList.join(','),
      'issue_date': issueDate.toIso8601String(),
      'return_status': returnStatus ? 1 : 0,
      'returned_at': returnedAt?.toIso8601String(),
      'converted_to_sale': convertedToSale ? 1 : 0,
      'sale_invoice_id': saleInvoiceId,
      'sold_status': soldStatus ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DealerIssueEntity.fromMap(Map<String, dynamic> map) {
    return DealerIssueEntity(
      issueId: map['issue_id'] as String,
      dealerId: map['dealer_id'] as String,
      imeiList: (map['imei_list'] as String).split(',').where((e) => e.isNotEmpty).toList(),
      issueDate: DateTime.parse(map['issue_date'] as String),
      returnStatus: map['return_status'] == 1,
      returnedAt: map['returned_at'] != null ? DateTime.parse(map['returned_at'] as String) : null,
      convertedToSale: map['converted_to_sale'] == 1,
      saleInvoiceId: map['sale_invoice_id'] as String?,
      soldStatus: map['sold_status'] == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String get statusText {
    if (soldStatus) return 'Sold';
    if (convertedToSale) return 'Converted';
    if (returnStatus) return 'Returned';
    return 'Issued';
  }

  String get statusColor {
    if (soldStatus) return 'green';
    if (convertedToSale) return 'blue';
    if (returnStatus) return 'amber';
    return 'purple';
  }

  bool get canBeConverted => !soldStatus && !returnStatus && !convertedToSale;
  bool get canBeReturned => !soldStatus && !returnStatus && !convertedToSale;
  bool get canBeDeleted => !soldStatus && !returnStatus && !convertedToSale;
}