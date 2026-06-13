import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/bus_model.dart';
import '../../core/services/assignment_service.dart';
import 'management_screen.dart';

class ManageStudentsParentsScreen extends StatefulWidget {
  const ManageStudentsParentsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ManageStudentsParentsScreen> createState() => _ManageStudentsParentsScreenState();
}

class _ManageStudentsParentsScreenState extends State<ManageStudentsParentsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  List<BusModel> _buses = [];
  bool _loadingBuses = true;
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadBuses();
  }

  @override
  void didUpdateWidget(covariant ManageStudentsParentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _activeTab = widget.initialTab;
      });
    }
  }

  Future<void> _loadBuses() async {
    try {
      final buses = await _assignmentService.fetchBuses();
      if (mounted) {
        setState(() {
          _buses = buses;
          _loadingBuses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingBuses = false);
      }
    }
  }

  String _getBusName(String? busId) {
    if (busId == null || busId.isEmpty) return 'No Bus';
    for (final bus in _buses) {
      if (bus.id == busId) {
        return bus.busNumber;
      }
    }
    return 'No Bus';
  }

  String? _findParentName(List<QueryDocumentSnapshot> parents, String studentId) {
    for (var parent in parents) {
      final data = parent.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final children = data['childrenUids'] as List<dynamic>?;
      if (children != null && children.contains(studentId)) {
        return data['name'] ?? 'Unknown Parent';
      }
    }
    return null;
  }

  String? _findParentUid(List<QueryDocumentSnapshot> parents, String studentId) {
    for (var parent in parents) {
      final data = parent.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final children = data['childrenUids'] as List<dynamic>?;
      if (children != null && children.contains(studentId)) {
        return parent.id;
      }
    }
    return null;
  }

  Widget _buildTabSelector(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: _activeTab == 0 ? Colors.white : scheme.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Students List',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _activeTab == 0 ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.family_restroom_rounded,
                      color: _activeTab == 1 ? Colors.white : scheme.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Parents List',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _activeTab == 1 ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBuses) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore query error: ${snapshot.error}');
          return const Scaffold(body: Center(child: Text('Error loading users')));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        final studentDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return data != null && data['role'] == 'student';
        }).toList();

        final parentDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return data != null && data['role'] == 'parent';
        }).toList();

        if (_activeTab == 0) {
          // Render Students List
          final List<(String, String, String)> items = [];
          for (final doc in studentDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown Student';
            final grade = data['grade'] ?? 'N/A';
            final section = data['section'] ?? 'N/A';
            final status = data['status'] ?? 'active';
            final busId = data['assignedBusId'];

            final parentName = _findParentName(parentDocs, doc.id) ?? 'Not Linked';
            final busName = _getBusName(busId);

            final formattedStatus = status.isNotEmpty
                ? '${status[0].toUpperCase()}${status.substring(1)}'
                : 'Active';

            items.add((
              name,
              'Grade $grade-$section · Parent: $parentName · Bus: $busName',
              formattedStatus,
            ));
          }

          return Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _buildTabSelector(scheme),
                ),
                Expanded(
                  child: ManagementScreen(
                    title: 'Manage Students',
                    subtitle: 'Track school students and assign them specific bus lines.',
                    searchLabel: 'Search student',
                    actionLabel: 'Add Student',
                    onAction: () => Navigator.pushNamed(context, '/add-edit-student'),
                    items: items,
                    icon: Icons.school_rounded,
                    onItemTap: (index) {
                      if (studentDocs.isEmpty) return;
                      final doc = studentDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      data['parentUid'] = _findParentUid(parentDocs, doc.id);
                      Navigator.pushNamed(context, '/add-edit-student', arguments: data);
                    },
                  ),
                ),
              ],
            ),
          );
        } else {
          // Render Parents List
          final List<(String, String, String)> items = [];
          for (final doc in parentDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown Parent';
            final email = data['email'] ?? '';
            final phone = data['phone'] ?? '';
            final childrenUids = data['childrenUids'] as List<dynamic>? ?? [];

            final kidsCount = childrenUids.length;
            final List<String> childNames = [];
            
            // Loop students safely to avoid runtime TypeError
            for (final uid in childrenUids) {
              String? childName;
              for (final s in studentDocs) {
                if (s.id == uid) {
                  final sData = s.data() as Map<String, dynamic>?;
                  if (sData != null && sData['name'] != null) {
                    childName = sData['name'];
                  }
                  break;
                }
              }
              childNames.add(childName ?? 'Unknown');
            }

            final childrenNamesStr = childNames.isNotEmpty
                ? ' · Kids: ${childNames.join(", ")}'
                : ' · No kids linked';

            items.add((
              name,
              '$email · $phone$childrenNamesStr',
              '$kidsCount ${kidsCount == 1 ? "Kid" : "Kids"}',
            ));
          }

          return Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _buildTabSelector(scheme),
                ),
                Expanded(
                  child: ManagementScreen(
                    title: 'Manage Parents',
                    subtitle: 'Register new parents and associate children to them.',
                    searchLabel: 'Search parent',
                    actionLabel: 'Add Parent',
                    onAction: () => Navigator.pushNamed(context, '/add-edit-parent'),
                    items: items,
                    icon: Icons.family_restroom_rounded,
                    onItemTap: (index) {
                      if (parentDocs.isEmpty) return;
                      final doc = parentDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      Navigator.pushNamed(context, '/add-edit-parent', arguments: data);
                    },
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
