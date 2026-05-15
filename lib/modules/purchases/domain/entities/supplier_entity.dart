class SupplierEntity {
  const SupplierEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierEntity copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearContactPerson = false,
    bool clearPhone = false,
    bool clearEmail = false,
    bool clearAddress = false,
    bool clearNotes = false,
  }) {
    return SupplierEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson:
          clearContactPerson ? null : contactPerson ?? this.contactPerson,
      phone: clearPhone ? null : phone ?? this.phone,
      email: clearEmail ? null : email ?? this.email,
      address: clearAddress ? null : address ?? this.address,
      notes: clearNotes ? null : notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
