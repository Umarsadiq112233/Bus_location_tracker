import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'management_screen.dart';

class ManageSchoolsScreen extends StatelessWidget {
  const ManageSchoolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore query error: ${snapshot.error}');
          return _buildScreen(context, [], []);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        List<(String, String, String)> items = [];
        List<QueryDocumentSnapshot> sortedDocs = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          sortedDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

          for (final doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unnamed School';
            final address = data['address'] ?? '';
            final email = data['email'] ?? '';
            final status = data['status'] ?? 'active';
            final busIds = data['assignedBusIds'] as List<dynamic>? ?? [];

            final formattedStatus = status.isNotEmpty
                ? '${status[0].toUpperCase()}${status.substring(1)}'
                : 'Active';

            items.add((
              name,
              '$address · $email · ${busIds.length} Bus${busIds.length == 1 ? '' : 'es'}',
              formattedStatus,
            ));
          }
        }

        return _buildScreen(context, items, sortedDocs);
      },
    );
  }

  Widget _buildScreen(
    BuildContext context,
    List<(String, String, String)> items,
    List<DocumentSnapshot> docs,
  ) {
    return ManagementScreen(
      title: 'Manage Schools',
      subtitle: 'Register schools, assign buses, and create school admin accounts.',
      searchLabel: 'Search school',
      actionLabel: 'Add School',
      onAction: () => Navigator.pushNamed(context, '/add-edit-school'),
      items: items,
      icon: Icons.school_rounded,
      onItemTap: (index) {
        if (docs.isEmpty) return;
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        Navigator.pushNamed(context, '/add-edit-school', arguments: data);
      },
    );
  }
}
