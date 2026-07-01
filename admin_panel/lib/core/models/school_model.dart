import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String status;
  final List<String> assignedBusIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SchoolModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.status,
    required this.assignedBusIds,
    required this.createdAt,
    this.updatedAt,
  });

  factory SchoolModel.fromMap(Map<String, dynamic> map, String documentId) {
    List<String> busIds = [];
    if (map['assignedBusIds'] != null) {
      busIds = List<String>.from(map['assignedBusIds']);
    }

    return SchoolModel(
      id: documentId,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      status: map['status'] ?? 'active',
      assignedBusIds: busIds,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'status': status,
      'assignedBusIds': assignedBusIds,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
