class BrandEntity {
  const BrandEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BrandEntity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BrandEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
