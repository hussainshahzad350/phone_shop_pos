class CustomerOptionEntity {
  const CustomerOptionEntity({
    required this.id,
    required this.name,
    this.phone,
  });

  final String id;
  final String name;
  final String? phone;
}
