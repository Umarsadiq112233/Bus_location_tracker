import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/enums/user_role.dart';
import 'assignment_service.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AssignmentService _assignmentService = AssignmentService();

  Future<void> saveDriver({
    String? id,
    required String name,
    required String email,
    required String phone,
    required String licenseNumber,
    required int experienceYears,
    required String status,
    String? assignedBusId,
  }) async {
    // 1. Save or Update the Driver in 'users' collection with role 'driver'
    final data = {
      'name': name,
      'email': email,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'experienceYears': experienceYears,
      'role': UserRole.driver.name,
      'status': status,
    };

    String driverId;
    if (id != null && id.isNotEmpty) {
      driverId = id;
      data['updatedAt'] = Timestamp.now();
      await _firestore.collection('users').doc(id).update(data);
    } else {
      data['createdAt'] = Timestamp.now();
      final docRef = await _firestore.collection('users').add(data);
      driverId = docRef.id;
    }

    // 2. If a bus is selected, update relationships
    if (assignedBusId != null && assignedBusId.isNotEmpty) {
      // Fetch the route assigned to this bus if any, so we can make a full assignment
      final busDoc = await _firestore.collection('buses').doc(assignedBusId).get();
      final routeId = busDoc.data()?['assignedRouteId'] as String?;

      if (routeId != null && routeId.isNotEmpty) {
        // Complete Assignment (Bus + Driver + Route)
        await _assignmentService.assignBus(
          busId: assignedBusId,
          driverId: driverId,
          routeId: routeId,
        );
      } else {
        // Just link bus and driver
        await _firestore.collection('users').doc(driverId).update({'assignedBusId': assignedBusId});
        await _firestore.collection('buses').doc(assignedBusId).update({'assignedDriverId': driverId});
      }
    }
  }
}
