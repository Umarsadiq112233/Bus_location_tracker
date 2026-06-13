import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole? role;
  final String? assignedBusId;
  final String? licenseNumber;
  final int? experienceYears;
  final List<String>? childrenUids;
  final String? grade;
  final String? section;
  final String? pickupPoint;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.role,
    this.assignedBusId,
    this.licenseNumber,
    this.experienceYears,
    this.childrenUids,
    this.grade,
    this.section,
    this.pickupPoint,
    required this.createdAt,
  });

  bool get isProfileComplete {
    if (name.trim().isEmpty || phone.trim().isEmpty) return false;
    if (role == UserRole.driver) {
      if (licenseNumber == null || licenseNumber!.trim().isEmpty) return false;
    }
    return true;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    UserRole? parsedRole;
    try {
      if (map['role'] != null) {
        parsedRole = UserRole.values.firstWhere(
          (e) => e.name == map['role'],
        );
      }
    } catch (_) {
      // Keep null if role not found or not set
    }

    List<String>? parsedChildrenUids;
    if (map['childrenUids'] != null) {
      parsedChildrenUids = List<String>.from(map['childrenUids']);
    }

    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: parsedRole,
      assignedBusId: map['assignedBusId'],
      licenseNumber: map['licenseNumber'],
      experienceYears: map['experienceYears'] != null ? (map['experienceYears'] as num).toInt() : null,
      childrenUids: parsedChildrenUids,
      grade: map['grade'],
      section: map['section'],
      pickupPoint: map['pickupPoint'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      if (role != null) 'role': role!.name,
      if (assignedBusId != null) 'assignedBusId': assignedBusId,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (experienceYears != null) 'experienceYears': experienceYears,
      if (childrenUids != null) 'childrenUids': childrenUids,
      if (grade != null) 'grade': grade,
      if (section != null) 'section': section,
      if (pickupPoint != null) 'pickupPoint': pickupPoint,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
