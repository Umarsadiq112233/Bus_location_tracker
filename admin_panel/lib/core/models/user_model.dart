import '../../shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? licenseNumber;
  final int? experienceYears;
  final UserRole? role;
  final DateTime createdAt;
  final List<String>? childrenUids;
  final String? grade;
  final String? section;
  final String? assignedBusId;
  final String? status;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.licenseNumber,
    this.experienceYears,
    this.role,
    required this.createdAt,
    this.childrenUids,
    this.grade,
    this.section,
    this.assignedBusId,
    this.status,
  });

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
      licenseNumber: map['licenseNumber'],
      experienceYears: map['experienceYears'],
      role: parsedRole,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      childrenUids: parsedChildrenUids,
      grade: map['grade'],
      section: map['section'],
      assignedBusId: map['assignedBusId'],
      status: map['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (experienceYears != null) 'experienceYears': experienceYears,
      if (role != null) 'role': role!.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (childrenUids != null) 'childrenUids': childrenUids,
      if (grade != null) 'grade': grade,
      if (section != null) 'section': section,
      if (assignedBusId != null) 'assignedBusId': assignedBusId,
      if (status != null) 'status': status,
    };
  }
}
