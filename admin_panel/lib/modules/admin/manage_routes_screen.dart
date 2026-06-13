import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'management_screen.dart';

class ManageRoutesScreen extends StatelessWidget {
  const ManageRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('routes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore query error: ${snapshot.error}');
          return _buildManagementScreen(context, [], isLoading: false);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildManagementScreen(context, [], isLoading: true);
        }

        List<(String, String, String)> items = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          // Sort in memory to ensure all records (even with missing createdAt) are loaded
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unnamed Route';
            final start = data['startPoint'] ?? '';
            final end = data['endPoint'] ?? '';
            final stopsCount = data['stopsCount'] ?? 0;
            final status = data['status'] ?? 'Active';

            // Capitalize first letter of status for styling consistency
            final formattedStatus = status.isNotEmpty
                ? '${status[0].toUpperCase()}${status.substring(1)}'
                : 'Active';

            items.add((
              name,
              'Start: $start · End: $end · $stopsCount Stops',
              formattedStatus,
            ));
          }
        }
        
        return _buildManagementScreen(context, items, isLoading: false);
      },
    );
  }

  Widget _buildManagementScreen(BuildContext context, List<(String, String, String)> items, {required bool isLoading}) {
    return ManagementScreen(
      title: 'Manage Routes',
      subtitle: 'Create route paths and define pick/drop stops.',
      searchLabel: 'Search route',
      actionLabel: 'Add Route',
      onAction: () async {
        await Navigator.pushNamed(context, '/add-edit-route');
      },
      // If loading, you can pass an empty list, but better to just show it
      items: items,
      icon: Icons.alt_route_rounded,
    );
  }
}
