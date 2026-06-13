import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/widgets/empty_state_widget.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

class StudentTripHistoryScreen extends StatefulWidget {
  final UserModel? student;
  const StudentTripHistoryScreen({super.key, this.student});

  @override
  State<StudentTripHistoryScreen> createState() =>
      _StudentTripHistoryScreenState();
}

class _StudentTripHistoryScreenState extends State<StudentTripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTripDate(DateTime dt) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${_monthName(dt.month)} ${dt.day}';
    } else if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday, ${_monthName(dt.month)} ${dt.day}';
    }

    final List<String> weekdays = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ];
    final weekdayStr = weekdays[dt.weekday % 7];
    return '$weekdayStr, ${_monthName(dt.month)} ${dt.day}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busId = widget.student?.assignedBusId;

    if (busId == null || busId.isEmpty) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          title: const Text(
            'Trip History',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: false,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: EmptyStateWidget(
              icon: Icons.directions_bus_rounded,
              title: 'No Bus Assigned',
              message:
                  'You are not assigned to any bus yet. Please contact the administrator.',
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('busId', isEqualTo: busId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: scheme.surface,
            body: const ListSkeleton(itemCount: 4, cardHeight: 120, borderRadius: 18),
          );
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        );

        // Sort in memory to avoid needing a composite index in Firestore
        docs.sort((a, b) {
          final aTime =
              (a.data()['startTime'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              (b.data()['startTime'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        // Map docs to _TripData models
        final List<_TripData> tripsList = docs.map((doc) {
          final data = doc.data();
          final startTime = (data['startTime'] as Timestamp?)?.toDate();
          final endTime = (data['endTime'] as Timestamp?)?.toDate();

          final dateStr = startTime != null ? _formatTripDate(startTime) : '—';
          final pickupTimeStr = startTime != null
              ? _formatTime(startTime)
              : '—';
          final arrivalTimeStr = endTime != null ? _formatTime(endTime) : '—';

          final statusStr = data['status'] as String? ?? 'completed';
          _TripStatus statusVal = _TripStatus.completed;
          if (statusStr == 'delayed') {
            statusVal = _TripStatus.delayed;
          } else if (statusStr == 'missed') {
            statusVal = _TripStatus.missed;
          } else if (statusStr == 'active') {
            statusVal = _TripStatus.active;
          }

          final durationStr = data['duration'] as String? ?? '—';

          return _TripData(
            date: dateStr,
            busNumber: data['busNumber'] as String? ?? 'Bus',
            route: data['routeName'] as String? ?? 'Route',
            pickupTime: pickupTimeStr,
            arrivalTime: arrivalTimeStr,
            status: statusVal,
            stops: (data['stopsCount'] as num?)?.toInt() ?? 0,
            duration: durationStr.isNotEmpty ? durationStr : '—',
            rawStartTime: startTime,
          );
        }).toList();

        final completedTrips = tripsList
            .where((t) => t.status == _TripStatus.completed)
            .length;
        final totalTrips = tripsList.length;
        final attendance = totalTrips > 0
            ? ((completedTrips / totalTrips) * 100).round()
            : 100;

        // Filter this week trips
        final now = DateTime.now();
        final oneWeekAgo = now.subtract(const Duration(days: 7));
        final thisWeekTripsList = tripsList.where((t) {
          return t.rawStartTime != null && t.rawStartTime!.isAfter(oneWeekAgo);
        }).toList();

        return Scaffold(
          backgroundColor: scheme.surface,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: scheme.surface,
                foregroundColor: scheme.onSurface,
                title: const Text(
                  'Trip History',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                centerTitle: false,
                bottom: TabBar(
                  controller: _tabController,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  indicatorColor: scheme.primary,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'All Trips'),
                    Tab(text: 'This Week'),
                  ],
                ),
              ),

              // Stats Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: '$completedTrips',
                          label: 'Completed',
                          color: AppColors.success,
                          icon: Icons.check_circle_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          value: '$totalTrips',
                          label: 'Total Trips',
                          color: scheme.primary,
                          icon: Icons.directions_bus_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          value: '$attendance%',
                          label: 'Attendance',
                          color: const Color(0xFF7B2FBE),
                          icon: Icons.bar_chart_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: tripsList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: EmptyStateWidget(
                        icon: Icons.history_rounded,
                        title: 'No Trip History',
                        message: 'No trips have been logged for your bus yet.',
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TripList(trips: tripsList),
                      _TripList(trips: thisWeekTripsList),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});

  final List<_TripData> trips;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _TripCard(trip: trips[index]),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final _TripData trip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    Color statusBg;

    switch (trip.status) {
      case _TripStatus.completed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Completed';
        statusBg = isDark ? const Color(0xFF0D2A1A) : const Color(0xFFF0FBF4);
        break;
      case _TripStatus.delayed:
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Delayed';
        statusBg = isDark ? const Color(0xFF3D2200) : const Color(0xFFFFF3E0);
        break;
      case _TripStatus.missed:
        statusColor = AppColors.danger;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Missed';
        statusBg = isDark ? const Color(0xFF3D0D0D) : const Color(0xFFFFF0F0);
        break;
      case _TripStatus.active:
        statusColor = scheme.primary;
        statusIcon = Icons.directions_bus_rounded;
        statusLabel = 'On the Way';
        statusBg = isDark ? const Color(0xFF0D1D2A) : const Color(0xFFE3F2FD);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  trip.date,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TripDetail(
                        icon: Icons.directions_bus_rounded,
                        label: 'Bus',
                        value: trip.busNumber,
                        color: scheme.primary,
                      ),
                    ),
                    Expanded(
                      child: _TripDetail(
                        icon: Icons.route_rounded,
                        label: 'Route',
                        value: trip.route,
                        color: const Color(0xFF7B2FBE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      _TimeBlock(
                        label: 'Pickup',
                        time: trip.pickupTime,
                        icon: Icons.login_rounded,
                        color: AppColors.success,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            Text(
                              trip.duration,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TimeBlock(
                        label: 'Arrival',
                        time: trip.arrivalTime,
                        icon: Icons.logout_rounded,
                        color: scheme.primary,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TripDetail extends StatelessWidget {
  const _TripDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  final String label;
  final String time;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// Data classes
enum _TripStatus { completed, delayed, missed, active }

class _TripData {
  const _TripData({
    required this.date,
    required this.busNumber,
    required this.route,
    required this.pickupTime,
    required this.arrivalTime,
    required this.status,
    required this.stops,
    required this.duration,
    required this.rawStartTime,
  });

  final String date;
  final String busNumber;
  final String route;
  final String pickupTime;
  final String arrivalTime;
  final _TripStatus status;
  final int stops;
  final String duration;
  final DateTime? rawStartTime;
}
