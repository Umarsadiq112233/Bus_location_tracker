import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key, this.showAppShell = true});

  final bool showAppShell;

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.uid;

    final content = Scaffold(
      backgroundColor: AppColors.surfaceTint,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: showAppShell
                        ? () => Navigator.maybePop(context)
                        : () {},
                  ),
                  const Expanded(
                    child: Text(
                      'Notification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.done_all_rounded,
                    onTap: () async {
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userId != null
                    ? NotificationService().getNotificationsStream(userId)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListSkeleton(itemCount: 4, cardHeight: 90, borderRadius: 16);
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs =
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                        snapshot.data?.docs ?? [],
                      );
                  if (docs.isNotEmpty) {
                    docs.sort((a, b) {
                      final aTime =
                          (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime =
                          (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
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
                            const SizedBox(height: 20),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Group into today and earlier
                  final todayDocs =
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final earlierDocs =
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

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
                      todayDocs.add(doc);
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    children: [
                      if (todayDocs.isNotEmpty) ...[
                        const _GroupTitle('Today'),
                        ...todayDocs.map((doc) => _buildTile(context, doc)),
                      ],
                      if (earlierDocs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const _GroupTitle('Earlier'),
                        ...earlierDocs.map((doc) => _buildTile(context, doc)),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }

  Widget _buildTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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
          return const Color(0xFF17B87A);
        case 'approaching_stop':
        case 'eta_update':
          return AppColors.primary;
        case 'delay_alert':
          return const Color(0xFFF2C14E);
        default:
          return AppColors.primary;
      }
    }

    IconData getStatusIcon() {
      switch (type) {
        case 'bus_started':
          return Icons.directions_bus_filled_rounded;
        case 'reached_school':
          return Icons.verified_rounded;
        case 'arrived':
          return Icons.location_on_rounded;
        case 'approaching_stop':
          return Icons.apartment_rounded;
        case 'eta_update':
          return Icons.timer_outlined;
        case 'delay_alert':
          return Icons.warning_amber_rounded;
        default:
          return Icons.notifications_active_rounded;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: GestureDetector(
        onTap: () {
          if (isUnread) {
            NotificationService().markAsRead(doc.id);
          }
        },
        child: _NotificationTile(
          icon: getStatusIcon(),
          title: title,
          body: message,
          time: _formatTimestamp(createdAt),
          color: getStatusColor(),
          unread: isUnread,
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
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour ; $minute';
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 22)),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF66717A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.color,
    this.unread = false,
    this.unreadColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final String time;
  final Color color;
  final bool unread;
  final Color? unreadColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: color),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: .16),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4E5961),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF5D6165),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: unread || unreadColor != null
                        ? unreadColor ?? AppColors.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
