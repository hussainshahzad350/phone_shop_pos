class RepairJobEntity {
  const RepairJobEntity({
    required this.id,
    required this.repairDate,
    required this.phoneModel,
    required this.problemDescription,
    required this.status,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.imei,
    this.accessories,
    this.technicianName,
    this.issueType,
    this.estimatedCost,
    this.advanceReceived = 0,
    this.finalCost,
    this.repairExpense = 0,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final DateTime repairDate;
  final String phoneModel;
  final String problemDescription;
  final String status;
  final DateTime createdAt;

  final String? customerName;
  final String? customerPhone;
  final String? imei;
  final String? accessories;
  final String? technicianName;
  /// Optional structured issue category for cleaner analytics.
  final String? issueType;
  final double? estimatedCost;
  final double advanceReceived;
  final double? finalCost;
  final double repairExpense;
  final String? notes;
  final DateTime? updatedAt;

  double get netProfit => (finalCost ?? 0) - repairExpense;

  double get remainingPayment => (finalCost ?? 0) - advanceReceived;

  static const String statusReceived = 'received';
  static const String statusDiagnosing = 'diagnosing';
  static const String statusRepairing = 'repairing';
  static const String statusReady = 'ready';
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';

  static const List<String> allStatuses = <String>[
    statusReceived,
    statusDiagnosing,
    statusRepairing,
    statusReady,
    statusDelivered,
    statusCancelled,
  ];

  static const List<String> allIssueTypes = <String>[
    'LCD / Display',
    'Battery',
    'Charging',
    'Mic',
    'Speaker',
    'Camera',
    'Network / SIM',
    'Water Damage',
    'Software / Flash',
    'Power Button',
    'Volume Button',
    'Back Cover',
    'Dead',
    'Other',
  ];

  RepairJobEntity copyWith({
    String? id,
    DateTime? repairDate,
    String? phoneModel,
    String? problemDescription,
    String? status,
    DateTime? createdAt,
    String? customerName,
    String? customerPhone,
    String? imei,
    String? accessories,
    String? technicianName,
    String? issueType,
    double? estimatedCost,
    double? advanceReceived,
    double? finalCost,
    double? repairExpense,
    String? notes,
    DateTime? updatedAt,
    bool clearCustomerName = false,
    bool clearCustomerPhone = false,
    bool clearImei = false,
    bool clearAccessories = false,
    bool clearTechnicianName = false,
    bool clearIssueType = false,
    bool clearEstimatedCost = false,
    bool clearFinalCost = false,
    bool clearNotes = false,
    bool clearUpdatedAt = false,
  }) {
    return RepairJobEntity(
      id: id ?? this.id,
      repairDate: repairDate ?? this.repairDate,
      phoneModel: phoneModel ?? this.phoneModel,
      problemDescription: problemDescription ?? this.problemDescription,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      customerName:
          clearCustomerName ? null : (customerName ?? this.customerName),
      customerPhone:
          clearCustomerPhone ? null : (customerPhone ?? this.customerPhone),
      imei: clearImei ? null : (imei ?? this.imei),
      accessories: clearAccessories ? null : (accessories ?? this.accessories),
      technicianName: clearTechnicianName
          ? null
          : (technicianName ?? this.technicianName),
      issueType: clearIssueType ? null : (issueType ?? this.issueType),
      estimatedCost:
          clearEstimatedCost ? null : (estimatedCost ?? this.estimatedCost),
      advanceReceived: advanceReceived ?? this.advanceReceived,
      finalCost: clearFinalCost ? null : (finalCost ?? this.finalCost),
      repairExpense: repairExpense ?? this.repairExpense,
      notes: clearNotes ? null : (notes ?? this.notes),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }
}
