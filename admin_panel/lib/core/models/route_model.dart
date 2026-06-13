class RouteModel {
  final String id;
  final String name;
  final String startPoint;
  final String endPoint;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final List<dynamic>? stops; // List of Map containing name, lat, lng

  RouteModel({
    required this.id,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.stops,
  });

  factory RouteModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RouteModel(
      id: documentId,
      name: map['name'] ?? '',
      startPoint: map['startPoint'] ?? '',
      endPoint: map['endPoint'] ?? '',
      startLat: map['startLatitude'] != null ? (map['startLatitude'] as num).toDouble() : null,
      startLng: map['startLongitude'] != null ? (map['startLongitude'] as num).toDouble() : null,
      endLat: map['endLatitude'] != null ? (map['endLatitude'] as num).toDouble() : null,
      endLng: map['endLongitude'] != null ? (map['endLongitude'] as num).toDouble() : null,
      stops: map['stopsList'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startPoint': startPoint,
      'endPoint': endPoint,
      if (startLat != null) 'startLatitude': startLat,
      if (startLng != null) 'startLongitude': startLng,
      if (endLat != null) 'endLatitude': endLat,
      if (endLng != null) 'endLongitude': endLng,
      if (stops != null) 'stopsList': stops,
    };
  }
}
