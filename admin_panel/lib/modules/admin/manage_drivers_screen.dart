import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'management_screen.dart';

class ManageDriversScreen extends StatelessWidget {
  const ManageDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore query error: ${snapshot.error}');
          return _buildManagementScreen(context, [], isLoading: false, docs: []);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildManagementScreen(context, [], isLoading: true, docs: []);
        }

        List<(String, String, String)> items = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown Driver';
            final license = data['licenseNumber'] ?? 'No License';
            final status = data['status'] ?? 'active';
            final assignedBus = data['assignedBusId'];

            final formattedStatus = status.isNotEmpty
                ? '${status[0].toUpperCase()}${status.substring(1)}'
                : 'Active';
            
            final busInfo = assignedBus != null && assignedBus.toString().isNotEmpty 
                ? 'Bus Assigned' 
                : 'No Bus';

            items.add((
              name,
              'License #$license · $busInfo',
              formattedStatus,
            ));
          }
        }
        
        return _buildManagementScreen(
          context, 
          items, 
          isLoading: false, 
          docs: snapshot.data?.docs ?? [],
        );
      },
    );
  }

  Widget _buildManagementScreen(
    BuildContext context, 
    List<(String, String, String)> items, 
    {required bool isLoading, required List<QueryDocumentSnapshot> docs}
  ) {
    return ManagementScreen(
      title: 'Manage Drivers',
      subtitle: 'Add, update and view active school bus drivers.',
      searchLabel: 'Search driver',
      actionLabel: 'Add Driver',
      onAction: () => Navigator.pushNamed(context, '/add-edit-driver'),
      items: items,
      icon: Icons.badge_rounded,
      onItemTap: (index) {
        if (docs.isEmpty) return;
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        Navigator.pushNamed(context, '/add-edit-driver', arguments: data);
      },
    );
  }
}
