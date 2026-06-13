class BusModel {
  final String id;
  final String busNumber;
  final String plateNumber;
  final int capacity;
  final String status;
  final String? assignedDriverId;
  final String? assignedRouteId;

  BusModel({
    required this.id,
    required this.busNumber,
    required this.plateNumber,
    required this.capacity,
    required this.status,
    this.assignedDriverId,
    this.assignedRouteId,
  });

  factory BusModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BusModel(
      id: documentId,
      busNumber: map['busNumber'] ?? '',
      plateNumber: map['plateNumber'] ?? '',
      capacity: map['capacity'] ?? 0,
      status: map['status'] ?? 'active',
      assignedDriverId: map['assignedDriverId'],
      assignedRouteId: map['assignedRouteId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'capacity': capacity,
      'status': status,
      if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
      if (assignedRouteId != null) 'assignedRouteId': assignedRouteId,
    };
  }
}
