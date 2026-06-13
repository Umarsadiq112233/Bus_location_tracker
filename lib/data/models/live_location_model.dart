class LiveLocationModel {
  const LiveLocationModel({
    required this.busId,
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.status,
    required this.updatedAt,
  });

  final String busId;
  final String driverId;
  final double latitude;
  final double longitude;
  final double speed;
  final String status;
  final DateTime updatedAt;

  factory LiveLocationModel.fromJson(Map<String, dynamic> json) {
    return LiveLocationModel(
      busId: json['busId'] as String? ?? '',
      driverId: json['driverId'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'offline',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'status': status,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  LiveLocationModel copyWith({
    String? busId,
    String? driverId,
    double? latitude,
    double? longitude,
    double? speed,
    String? status,
    DateTime? updatedAt,
  }) {
    return LiveLocationModel(
      busId: busId ?? this.busId,
      driverId: driverId ?? this.driverId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
