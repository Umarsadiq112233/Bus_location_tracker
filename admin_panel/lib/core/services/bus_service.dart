import 'package:cloud_firestore/cloud_firestore.dart';

import 'assignment_service.dart';

class BusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AssignmentService _assignmentService = AssignmentService();

  Future<void> saveBus({
    String? id,
    required String busNumber,
    required String plateNumber,
    required int capacity,
    required String status,
    String? driverId,
    String? routeId,
  }) async {
    String busId;
    final payload = {
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'capacity': capacity,
      'status': status,
      if (id == null) 'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    if (id != null) {
      busId = id;
      await _firestore.collection('buses').doc(busId).update(payload);
    } else {
      final docRef = await _firestore.collection('buses').add(payload);
      busId = docRef.id;
    }

    // 2. If a driver and a route are provided, use the existing logic to link them perfectly
    if (driverId != null && routeId != null && driverId.isNotEmpty && routeId.isNotEmpty) {
      await _assignmentService.assignBus(
        busId: busId,
        driverId: driverId,
        routeId: routeId,
      );
    } else if (driverId != null && driverId.isNotEmpty) {
      // If only driver is selected
      await _firestore.collection('buses').doc(busId).update({'assignedDriverId': driverId});
      await _firestore.collection('users').doc(driverId).update({'assignedBusId': busId});
    } else if (routeId != null && routeId.isNotEmpty) {
      // If only route is selected
      await _firestore.collection('buses').doc(busId).update({'assignedRouteId': routeId});
    }
  }
}
