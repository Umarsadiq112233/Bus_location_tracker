import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/school_model.dart';
import '../models/bus_model.dart';
import '../../shared/enums/user_role.dart';

class SchoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of all schools (real-time)
  Stream<List<SchoolModel>> getSchoolsStream() {
    return _firestore
        .collection('schools')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SchoolModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Fetch all schools (Future)
  Future<List<SchoolModel>> fetchAllSchools() async {
    final snapshot =
        await _firestore.collection('schools').orderBy('name').get();
    return snapshot.docs
        .map((doc) => SchoolModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Fetch a single school by ID
  Future<SchoolModel?> fetchSchoolById(String schoolId) async {
    final doc = await _firestore.collection('schools').doc(schoolId).get();
    if (doc.exists) {
      return SchoolModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Save school (create/update)
  Future<String> saveSchool({
    String? id,
    required String name,
    required String address,
    required String phone,
    required String email,
    required String status,
    required List<String> assignedBusIds,
  }) async {
    final data = {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'status': status,
      'assignedBusIds': assignedBusIds,
    };

    if (id != null && id.isNotEmpty) {
      data['updatedAt'] = Timestamp.now();
      await _firestore.collection('schools').doc(id).update(data);
      return id;
    } else {
      data['createdAt'] = Timestamp.now();
      final docRef = await _firestore.collection('schools').add(data);
      return docRef.id;
    }
  }

  // Delete school
  Future<void> deleteSchool(String schoolId) async {
    // Also remove schoolId from all users linked to this school
    final batch = _firestore.batch();

    // Remove school doc
    batch.delete(_firestore.collection('schools').doc(schoolId));

    // Find all users linked to this school and clear their schoolId
    final linkedUsers = await _firestore
        .collection('users')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    for (var doc in linkedUsers.docs) {
      batch.update(doc.reference, {'schoolId': FieldValue.delete()});
    }

    await batch.commit();
  }

  // Assign a bus to a school
  Future<void> assignBusToSchool(String schoolId, String busId) async {
    await _firestore.collection('schools').doc(schoolId).update({
      'assignedBusIds': FieldValue.arrayUnion([busId]),
    });
  }

  // Remove a bus from a school
  Future<void> removeBusFromSchool(String schoolId, String busId) async {
    await _firestore.collection('schools').doc(schoolId).update({
      'assignedBusIds': FieldValue.arrayRemove([busId]),
    });
  }

  // Fetch buses assigned to a specific school
  Future<List<BusModel>> fetchBusesForSchool(String schoolId) async {
    final schoolDoc =
        await _firestore.collection('schools').doc(schoolId).get();
    if (!schoolDoc.exists) return [];

    final assignedBusIds =
        List<String>.from(schoolDoc.data()?['assignedBusIds'] ?? []);
    if (assignedBusIds.isEmpty) return [];

    // Firestore 'whereIn' has a limit of 30 items per query
    final List<BusModel> buses = [];
    for (var i = 0; i < assignedBusIds.length; i += 30) {
      final chunk = assignedBusIds.sublist(
          i, i + 30 > assignedBusIds.length ? assignedBusIds.length : i + 30);
      final snapshot = await _firestore
          .collection('buses')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      buses.addAll(
          snapshot.docs.map((doc) => BusModel.fromMap(doc.data(), doc.id)));
    }

    return buses;
  }

  // Fetch the SchoolAdmin for a given school (1 per school)
  Future<Map<String, dynamic>?> fetchSchoolAdmin(String schoolId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.schoolAdmin.name)
        .where('schoolId', isEqualTo: schoolId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // Create SchoolAdmin user document in Firestore
  // (Firebase Auth account is created separately via client-side auth)
  Future<void> createSchoolAdminDoc({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String schoolId,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'role': UserRole.schoolAdmin.name,
      'schoolId': schoolId,
      'status': 'active',
      'createdAt': Timestamp.now(),
    });
  }
}
