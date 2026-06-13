import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static AuthService? _instance;

  factory AuthService() {
    return _instance ??= AuthService._internal();
  }

  AuthService._internal();

  static set instance(AuthService? mock) => _instance = mock;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login with Email/Password
  Future<UserModel?> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        return await getUserData(user.uid);
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  // Register with Email/Password
  Future<UserModel?> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone,
    UserRole role,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Create a new user document in Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  // Sign In with Google
  Future<UserModel?> signInWithGoogle({UserRole? defaultRole}) async {
    try {
      // Use the classic constructor with the server/web client ID from
      // google-services.json (oauth_client where client_type == 3).
      // This avoids the `serverClientId must be provided` crash that the
      // new GoogleSignIn.instance.authenticate() API throws on Android.
      const String serverClientId =
          '883729268140-kife7oq2vo3pfbibkk68i762phq3ej1c.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: serverClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        // Check if user document exists
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        } else {
          // New Google User - Save to Firestore
          UserModel newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? '',
            email: user.email ?? '',
            phone: user.phoneNumber ?? '',
            role: defaultRole,
            createdAt: DateTime.now(),
          );
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(newUser.toMap());
          return newUser;
        }
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  // Fetch User Data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  // Fetch Assigned Bus
  Future<BusModel?> fetchAssignedBus(String busId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('buses').doc(busId).get();
      if (doc.exists) {
        return BusModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching assigned bus: $e');
      return null;
    }
  }

  // Fetch Assigned Route
  Future<RouteModel?> fetchAssignedRoute(String routeId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('routes').doc(routeId).get();
      if (doc.exists) {
        return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching assigned route: $e');
      return null;
    }
  }

  // Update Bus Location
  Future<void> updateBusLocation({
    required String busId,
    required String driverId,
    required double lat,
    required double lng,
    required double speed,
    required String status,
  }) async {
    try {
      final batch = _firestore.batch();
      
      // Update buses collection
      final busRef = _firestore.collection('buses').doc(busId);
      batch.update(busRef, {
        'currentLat': lat,
        'currentLng': lng,
        'speed': speed.round(),
        'status': status,
      });

      // Update/Set live_locations collection
      final liveRef = _firestore.collection('live_locations').doc(busId);
      batch.set(liveRef, {
        'busId': busId,
        'driverId': driverId,
        'latitude': lat,
        'longitude': lng,
        'speed': speed.round(),
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error updating bus location: $e');
    }
  }

  // End Bus Trip
  Future<void> endBusTrip(String busId) async {
    try {
      final batch = _firestore.batch();

      // Update buses collection: clear coordinates and status back to normal/active
      final busRef = _firestore.collection('buses').doc(busId);
      batch.update(busRef, {
        'currentLat': FieldValue.delete(),
        'currentLng': FieldValue.delete(),
        'speed': 0,
        'status': 'active',
      });

      // Update live_locations collection to offline
      final liveRef = _firestore.collection('live_locations').doc(busId);
      batch.update(liveRef, {
        'status': 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error ending bus trip: $e');
    }
  }

  // Update User Profile Data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user data: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      try {
        NotificationService().stopListening();
      } catch (e) {
        debugPrint('Error stopping notifications listener: $e');
      }
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // Fetch children by their UIDs
  Future<List<UserModel>> fetchChildren(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      final query = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids)
          .get();
      return query.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching children: $e');
      return [];
    }
  }

  // Stream a single bus document
  Stream<BusModel?> streamBus(String busId) {
    return _firestore
        .collection('buses')
        .doc(busId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return BusModel.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
          }
          return null;
        });
  }

  // Fetch a student by email
  Future<UserModel?> fetchStudentByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: UserRole.student.name)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching student by email: $e');
      return null;
    }
  }

  // Link a child to parent's childrenUids list
  Future<void> linkChild(String parentUid, String childUid) async {
    try {
      await _firestore.collection('users').doc(parentUid).update({
        'childrenUids': FieldValue.arrayUnion([childUid]),
      });
    } catch (e) {
      debugPrint('Error linking child: $e');
      rethrow;
    }
  }

  // Unlink a child from parent's childrenUids list
  Future<void> unlinkChild(String parentUid, String childUid) async {
    try {
      await _firestore.collection('users').doc(parentUid).update({
        'childrenUids': FieldValue.arrayRemove([childUid]),
      });
    } catch (e) {
      debugPrint('Error unlinking child: $e');
      rethrow;
    }
  }

  // Fetch all students in the database
  Future<List<UserModel>> fetchAllStudents() async {
    try {
      final query = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.student.name)
          .get();
      return query.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all students: $e');
      return [];
    }
  }
}

