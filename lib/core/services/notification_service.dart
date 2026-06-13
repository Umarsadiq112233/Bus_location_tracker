import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/bus_tracker_app.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;
  DateTime? _listeningStartTime;

  Future<void> initialize() async {}

  // Listen to incoming notifications in real-time
  void listenToNotifications(String userId) {
    _subscription?.cancel();
    _listeningStartTime = DateTime.now();

    _subscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isEmpty) return;

            // Sort in memory to get the latest document without requiring a Firestore composite index
            final sortedDocs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.docs,
                );
            sortedDocs.sort((a, b) {
              final aTime =
                  (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime); // descending
            });

            final doc = sortedDocs.first;
            final data = doc.data();
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) return;

            final createdDateTime = createdAt.toDate();
            // Only display banner if the notification is created after starting to listen (last 10 seconds buffer)
            if (_listeningStartTime != null &&
                createdDateTime.isAfter(
                  _listeningStartTime!.subtract(const Duration(seconds: 10)),
                )) {
              // Prevent repeating for the same notification by adjusting listening start time
              _listeningStartTime = createdDateTime.add(
                const Duration(milliseconds: 100),
              );

              final title = data['title'] as String? ?? 'Notification';
              final body = data['body'] as String? ?? '';
              final type = data['type'] as String? ?? 'info';

              // Trigger local notification pop-up
              showLocalBanner(title: title, message: body, type: type);
            }
          },
          onError: (err) {
            debugPrint('Notifications listener error: $err');
          },
        );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Get real-time stream of notifications for a user
  Stream<QuerySnapshot<Map<String, dynamic>>> getNotificationsStream(
    String userId,
  ) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadQs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadQs.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in unreadQs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      debugPrint('Marked ${unreadQs.docs.length} notifications as read.');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Create notifications in Firestore dynamically for parents whose children are on this bus
  Future<void> sendTripNotification({
    required String busId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      // 1. Fetch all students assigned to this bus
      final studentsQs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('assignedBusId', isEqualTo: busId)
          .get();

      if (studentsQs.docs.isEmpty) {
        debugPrint('No students assigned to bus $busId for notifications.');
        return;
      }

      final studentIds = studentsQs.docs.map((doc) => doc.id).toList();

      // 2. Fetch all parents who have at least one of these student IDs linked
      // Firestore 'whereIn' is limited to 10 items. For simplicity and reliability in batching,
      // we fetch all parents and filter, or query parents linked to children in chunks.
      // Since childrenUids is an array, we query parents for each child, or batch check.
      final parentUids = <String>{};
      for (var studentId in studentIds) {
        final parentsQs = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'parent')
            .where('childrenUids', arrayContains: studentId)
            .get();
        for (var doc in parentsQs.docs) {
          parentUids.add(doc.id);
        }
      }

      if (parentUids.isEmpty && studentIds.isEmpty) {
        debugPrint('No parents or students found linked to bus $busId.');
        return;
      }

      final batch = _firestore.batch();
      for (var parentUid in parentUids) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, {
          'userId': parentUid,
          'title': title,
          'body': body,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      for (var studentId in studentIds) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, {
          'userId': studentId,
          'title': title,
          'body': body,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
      debugPrint(
        'Successfully sent notification to ${parentUids.length} parents and ${studentIds.length} students.',
      );
    } catch (e) {
      debugPrint('Error sending trip notifications: $e');
    }
  }

  // Show a professional overlay banner on top of the screen
  void showLocalBanner({
    required String title,
    required String message,
    required String type,
  }) {
    final overlayState = BusTrackerApp.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedBanner(
        title: title,
        message: message,
        type: type,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

// ───────────────────────────────────────────────────────────────
// Animated Overlay Notification Banner Widget
// ───────────────────────────────────────────────────────────────
class _AnimatedBanner extends StatefulWidget {
  const _AnimatedBanner({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final String type;
  final VoidCallback onDismiss;

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _getTypeColor() {
    switch (widget.type) {
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

  IconData _getTypeIcon() {
    switch (widget.type) {
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

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final statusColor = _getTypeColor();

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: statusColor.withValues(alpha: .28),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getTypeIcon(), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
