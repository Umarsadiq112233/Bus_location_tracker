import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../shared/enums/user_role.dart';

class ParentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of parents
  Stream<List<UserModel>> getParentsStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.parent.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Fetch all parents (Future)
  Future<List<UserModel>> fetchAllParents() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.parent.name)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Save parent (create/update) and link selected children
  Future<void> saveParent({
    String? id,
    required String name,
    required String email,
    required String phone,
    required String status,
    required List<String> childrenUids,
  }) async {
    final data = {
      'name': name,
      'email': email,
      'phone': phone,
      'status': status,
      'role': UserRole.parent.name,
      'childrenUids': childrenUids,
    };

    if (id != null && id.isNotEmpty) {
      data['updatedAt'] = Timestamp.now();
      await _firestore.collection('users').doc(id).update(data);
    } else {
      data['createdAt'] = Timestamp.now();
      await _firestore.collection('users').add(data);
    }
  }

  // Delete parent and unlink from students (students remain in DB but are no longer linked)
  Future<void> deleteParent(String parentId) async {
    await _firestore.collection('users').doc(parentId).delete();
  }
}
