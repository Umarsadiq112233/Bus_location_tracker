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
  final String? schoolId;

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
    this.schoolId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    UserRole? parsedRole;
    try {
      if (map['role'] != null) {
        final roleStr = map['role'].toString().toLowerCase().trim();
        parsedRole = UserRole.values.firstWhere(
          (e) => e.name.toLowerCase() == roleStr,
        );
      }
    } catch (_) {
      // Keep null if role not found or not set
    }

    List<String>? parsedChildrenUids;
    if (map['childrenUids'] != null) {
      try {
        parsedChildrenUids = List<String>.from(map['childrenUids'] as Iterable);
      } catch (_) {
        // Fallback if not an iterable of strings
      }
    }

    DateTime parsedCreatedAt;
    try {
      final val = map['createdAt'];
      if (val is Timestamp) {
        parsedCreatedAt = val.toDate();
      } else if (val is String) {
        parsedCreatedAt = DateTime.tryParse(val) ?? DateTime.now();
      } else if (val is int) {
        parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(val);
      } else {
        parsedCreatedAt = DateTime.now();
      }
    } catch (_) {
      parsedCreatedAt = DateTime.now();
    }

    int? parsedExpYears;
    if (map['experienceYears'] != null) {
      if (map['experienceYears'] is num) {
        parsedExpYears = (map['experienceYears'] as num).toInt();
      } else {
        parsedExpYears = int.tryParse(map['experienceYears'].toString());
      }
    }

    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      licenseNumber: map['licenseNumber'],
      experienceYears: parsedExpYears,
      role: parsedRole,
      createdAt: parsedCreatedAt,
      childrenUids: parsedChildrenUids,
      grade: map['grade'],
      section: map['section'],
      assignedBusId: map['assignedBusId'],
      status: map['status'] ?? 'active',
      schoolId: map['schoolId'],
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
      if (schoolId != null) 'schoolId': schoolId,
    };
  }
}
