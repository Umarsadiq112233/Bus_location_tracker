import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../shared/enums/user_role.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of students
  Stream<List<UserModel>> getStudentsStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.student.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Fetch all students (Future)
  Future<List<UserModel>> fetchAllStudents() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.student.name)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Save student (create/update) and optionally link to parent
  Future<void> saveStudent({
    String? id,
    required String name,
    required String email,
    required String phone,
    required String grade,
    required String section,
    String? assignedBusId,
    String? status,
    String? parentUid, // UID of the selected parent
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'phone': phone,
      'grade': grade,
      'section': section,
      'assignedBusId': assignedBusId ?? '',
      'status': status ?? 'active',
      'role': UserRole.student.name,
    };

    String studentId;
    if (id != null && id.isNotEmpty) {
      studentId = id;
      data['updatedAt'] = Timestamp.now();
      await _firestore.collection('users').doc(id).update(data);
    } else {
      data['createdAt'] = Timestamp.now();
      final docRef = await _firestore.collection('users').add(data);
      studentId = docRef.id;
    }

    // Handle parent linking:
    // 1. Unlink student from any parent that was previously linked (if their parent changed or is now unassigned)
    final currentParents = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.parent.name)
        .where('childrenUids', arrayContains: studentId)
        .get();

    final batch = _firestore.batch();

    for (var doc in currentParents.docs) {
      if (doc.id != parentUid) {
        batch.update(doc.reference, {
          'childrenUids': FieldValue.arrayRemove([studentId])
        });
      }
    }

    // 2. Link student to the new parent if specified
    if (parentUid != null && parentUid.isNotEmpty) {
      final parentRef = _firestore.collection('users').doc(parentUid);
      batch.update(parentRef, {
        'childrenUids': FieldValue.arrayUnion([studentId])
      });
    }

    await batch.commit();
  }

  // Delete student and unlink from parent
  Future<void> deleteStudent(String studentId) async {
    final batch = _firestore.batch();

    // Delete student document
    batch.delete(_firestore.collection('users').doc(studentId));

    // Remove from any parent's childrenUids list
    final parentsLinked = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.parent.name)
        .where('childrenUids', arrayContains: studentId)
        .get();

    for (var doc in parentsLinked.docs) {
      batch.update(doc.reference, {
        'childrenUids': FieldValue.arrayRemove([studentId])
      });
    }

    await batch.commit();
  }
}
