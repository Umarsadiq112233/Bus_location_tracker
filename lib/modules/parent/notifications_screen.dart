import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

// ═══════════════════════════════════════════════════════════════
// Parent Notifications Screen — Professional UI
// ═══════════════════════════════════════════════════════════════

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              if (userId != null) {
                await NotificationService().markAllAsRead(userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
            icon: const Icon(
              Icons.done_all_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userId != null
            ? NotificationService().getNotificationsStream(userId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton(itemCount: 4, cardHeight: 96, borderRadius: 16);
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
          if (docs.isNotEmpty) {
            docs.sort((a, b) {
              final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });
          }
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You will receive updates here when your child\'s bus trip starts or reaches school.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group into today and earlier
          final todayDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final earlierDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (var doc in docs) {
            final data = doc.data();
            final createdAtTimestamp = data['createdAt'] as Timestamp?;
            if (createdAtTimestamp != null) {
              if (_isToday(createdAtTimestamp.toDate())) {
                todayDocs.add(doc);
              } else {
                earlierDocs.add(doc);
              }
            } else {
              // serverTimestamp is not written yet in local cache
              todayDocs.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              if (todayDocs.isNotEmpty) ...[
                const _DateHeader('Today'),
                const SizedBox(height: 12),
                ...todayDocs.map((doc) => _buildCard(context, doc)),
                const SizedBox(height: 12),
              ],
              if (earlierDocs.isNotEmpty) ...[
                const _DateHeader('Earlier'),
                const SizedBox(height: 12),
                ...earlierDocs.map((doc) => _buildCard(context, doc)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String title = data['title'] as String? ?? 'Notification';
    final String message = data['body'] as String? ?? '';
    final String type = data['type'] as String? ?? 'info';
    final bool isUnread = !(data['isRead'] as bool? ?? false);
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    Color getStatusColor() {
      switch (type) {
        case 'bus_started':
        case 'reached_school':
        case 'arrived':
          return AppColors.success;
        case 'approaching_stop':
        case 'eta_update':
          return AppColors.primary;
        case 'delay_alert':
          return AppColors.warning;
        default:
          return AppColors.info;
      }
    }

    IconData getStatusIcon() {
      switch (type) {
        case 'bus_started':
          return Icons.directions_bus_filled_rounded;
        case 'reached_school':
          return Icons.school_rounded;
        case 'arrived':
          return Icons.location_on_rounded;
        case 'approaching_stop':
          return Icons.near_me_rounded;
        case 'eta_update':
          return Icons.access_time_filled_rounded;
        case 'delay_alert':
          return Icons.warning_amber_rounded;
        default:
          return Icons.notifications_active_rounded;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          if (isUnread) {
            NotificationService().markAsRead(doc.id);
          }
        },
        child: _NotificationCard(
          title: title,
          message: message,
          time: _formatTimestamp(createdAt),
          icon: getStatusIcon(),
          color: getStatusColor(),
          isUnread: isUnread,
        ),
      ),
    );
  }
}

bool _isToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

String _formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return 'Just now';
  final dt = timestamp.toDate();
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}


class _DateHeader extends StatelessWidget {
  const _DateHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.isUnread,
  });

  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : Colors.white.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? color.withValues(alpha: .2) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: isUnread ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isUnread)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? color.withValues(alpha: .12)
                        : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isUnread ? color : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                          color: isUnread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnread
                              ? AppColors.textSecondary
                              : AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
