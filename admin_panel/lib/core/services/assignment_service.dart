import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../models/user_model.dart';
import '../models/route_model.dart';
import '../../shared/enums/user_role.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all buses. If the collection is empty, seed mock data.
  Future<List<BusModel>> fetchBuses() async {
    final snapshot = await _firestore.collection('buses').get();
    if (snapshot.docs.isEmpty) {
      // Seed mock buses
      final mockBuses = [
        {'busNumber': 'BLT-24', 'plateNumber': 'Plate KHI-204', 'status': 'active'},
        {'busNumber': 'BLT-18', 'plateNumber': 'Plate KHI-118', 'status': 'active'},
        {'busNumber': 'BLT-07', 'plateNumber': 'Plate KHI-707', 'status': 'maintenance'},
      ];
      final List<BusModel> busesList = [];
      for (var data in mockBuses) {
        final docRef = await _firestore.collection('buses').add(data);
        busesList.add(BusModel.fromMap(data, docRef.id));
      }
      return busesList;
    }
    return snapshot.docs.map((doc) => BusModel.fromMap(doc.data(), doc.id)).toList();
  }

  // Fetch all drivers. If the collection is empty, seed mock data.
  Future<List<UserModel>> fetchDrivers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.driver.name)
        .get();
        
    if (snapshot.docs.isEmpty) {
      // Seed mock driver users
      final mockDrivers = [
        {'name': 'Ahmed Raza', 'email': 'driver.ahmed@school.edu', 'phone': '+1 555-0101', 'role': 'driver', 'createdAt': Timestamp.now()},
        {'name': 'Bilal Khan', 'email': 'driver.bilal@school.edu', 'phone': '+1 555-0102', 'role': 'driver', 'createdAt': Timestamp.now()},
        {'name': 'Muhammad Ali', 'email': 'driver.ali@school.edu', 'phone': '+1 555-0103', 'role': 'driver', 'createdAt': Timestamp.now()},
      ];
      final List<UserModel> driversList = [];
      for (var data in mockDrivers) {
        final docRef = await _firestore.collection('users').add(data);
        driversList.add(UserModel.fromMap(data, docRef.id));
      }
      return driversList;
    }
    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
  }

  // Fetch all routes. If empty, seed mock data.
  Future<List<RouteModel>> fetchRoutes() async {
    final snapshot = await _firestore.collection('routes').get();
    if (snapshot.docs.isEmpty) {
      // Seed mock routes
      final mockRoutes = [
        {'name': 'North Campus Loop', 'startPoint': 'Main Gate', 'endPoint': 'North Block'},
        {'name': 'Gulshan Express', 'startPoint': 'Civic Center', 'endPoint': 'Campus'},
        {'name': 'Main Campus Express', 'startPoint': 'Saddar Metro', 'endPoint': 'Admin Complex'},
      ];
      final List<RouteModel> routesList = [];
      for (var data in mockRoutes) {
        final docRef = await _firestore.collection('routes').add(data);
        routesList.add(RouteModel.fromMap(data, docRef.id));
      }
      return routesList;
    }
    return snapshot.docs.map((doc) => RouteModel.fromMap(doc.data(), doc.id)).toList();
  }

  // Create Assignment transaction with perfect cleanups
  Future<void> assignBus({
    required String busId,
    required String driverId,
    required String routeId,
  }) async {
    // 1. Fetch current states to find previous assignments
    final driverDoc = await _firestore.collection('users').doc(driverId).get();
    final String? oldBusId = driverDoc.data()?['assignedBusId'] as String?;

    final busDoc = await _firestore.collection('buses').doc(busId).get();
    final String? oldDriverId = busDoc.data()?['assignedDriverId'] as String?;

    final batch = _firestore.batch();

    // 2. Clear old driver's assignment if the bus was assigned to a different driver
    if (oldDriverId != null && oldDriverId != driverId) {
      batch.update(_firestore.collection('users').doc(oldDriverId), {
        'assignedBusId': FieldValue.delete(),
      });
    }

    // 3. Clear old bus's assignments if the driver was assigned to a different bus
    if (oldBusId != null && oldBusId != busId) {
      batch.update(_firestore.collection('buses').doc(oldBusId), {
        'assignedDriverId': FieldValue.delete(),
        'assignedRouteId': FieldValue.delete(),
      });
      batch.delete(_firestore.collection('assignments').doc(oldBusId));
    }

    // 4. Find any other drivers currently assigned to this new bus and clear them
    final otherDrivers = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.driver.name)
        .where('assignedBusId', isEqualTo: busId)
        .get();
    for (var doc in otherDrivers.docs) {
      if (doc.id != driverId) {
        batch.update(doc.reference, {
          'assignedBusId': FieldValue.delete(),
        });
      }
    }

    // 5. Create/Update the current assignments document
    final assignmentRef = _firestore.collection('assignments').doc(busId);
    batch.set(assignmentRef, {
      'busId': busId,
      'driverId': driverId,
      'routeId': routeId,
      'assignedAt': Timestamp.now(),
      'status': 'active',
    });

    // 6. Update the Bus document to link Driver and Route
    final busRef = _firestore.collection('buses').doc(busId);
    batch.update(busRef, {
      'assignedDriverId': driverId,
      'assignedRouteId': routeId,
    });

    // 7. Update the Driver's user profile to link the assigned Bus
    final driverRef = _firestore.collection('users').doc(driverId);
    batch.update(driverRef, {
      'assignedBusId': busId,
    });

    // Commit batch
    await batch.commit();
  }
}
