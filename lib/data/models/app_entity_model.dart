class AppEntityModel {
  const AppEntityModel({
    required this.id,
    required this.name,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final Map<String, dynamic> metadata;

  factory AppEntityModel.fromJson(Map<String, dynamic> json) {
    return AppEntityModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'metadata': metadata};
  }

  AppEntityModel copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? metadata,
  }) {
    return AppEntityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      metadata: metadata ?? this.metadata,
    );
  }
}
