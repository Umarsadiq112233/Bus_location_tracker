import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'management_screen.dart';

class ManageBusesScreen extends StatelessWidget {
  const ManageBusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('buses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore query error: ${snapshot.error}');
          return _buildManagementScreen(context, [], [], isLoading: false);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildManagementScreen(context, [], [], isLoading: true);
        }

        List<(String, String, String)> items = [];
        List<QueryDocumentSnapshot> sortedDocs = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          sortedDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          // Sort in memory to ensure all records (even with missing createdAt) are loaded
          sortedDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          for (final doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final busNumber = data['busNumber'] ?? 'Unnamed Bus';
            final plateNumber = data['plateNumber'] ?? '';
            final status = data['status'] ?? 'active';
            final capacity = data['capacity']?.toString() ?? '40';
            
            final driverId = data['assignedDriverId'];
            final routeId = data['assignedRouteId'];
            
            String assignmentStr = 'No driver or route';
            if (driverId != null && routeId != null) {
               assignmentStr = 'Driver & Route assigned';
            } else if (driverId != null) {
               assignmentStr = 'Driver assigned';
            } else if (routeId != null) {
               assignmentStr = 'Route assigned';
            }

            final formattedStatus = status.isNotEmpty
                ? '${status[0].toUpperCase()}${status.substring(1)}'
                : 'Active';

            items.add((
              busNumber,
              'Plate $plateNumber · Cap: $capacity · $assignmentStr',
              formattedStatus,
            ));
          }
        }
        
        return _buildManagementScreen(context, items, sortedDocs, isLoading: false);
      },
    );
  }

  Widget _buildManagementScreen(BuildContext context, List<(String, String, String)> items, List<DocumentSnapshot> docs, {required bool isLoading}) {
    return ManagementScreen(
      title: 'Manage Buses',
      subtitle: 'Add bus, review GPS unit, and monitor current status.',
      searchLabel: 'Search bus',
      actionLabel: 'Add Bus',
      onAction: () async {
        await Navigator.pushNamed(context, '/add-edit-bus');
      },
      items: items,
      icon: Icons.directions_bus_rounded,
      onItemTap: (index) {
        if (docs.isEmpty) return;
        final doc = docs[index];
        Navigator.pushNamed(context, '/add-edit-bus', arguments: {
          'id': doc.id,
          'data': doc.data(),
        });
      },
      onViewLive: (index) {
        if (docs.isEmpty) return;
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        if (data['currentLat'] == null || data['currentLng'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This bus is currently offline (No GPS Data). Cannot track live.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        Navigator.pushNamed(context, '/admin-live-tracking', arguments: doc.id);
      },
    );
  }
}
