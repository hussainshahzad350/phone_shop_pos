class SupplierOptionEntity {
  const SupplierOptionEntity({
    required this.id,
    required this.name,
    this.phone,
    this.contactPerson,
  });

  final String id;
  final String name;
  final String? phone;
  final String? contactPerson;
}
