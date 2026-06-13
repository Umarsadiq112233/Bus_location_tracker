import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Trip History Screen — Professional UI
// ═══════════════════════════════════════════════════════════════

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Trip History',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.filter_list_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          const _MonthHeader('June 2026'),
          const SizedBox(height: 14),
          _HistoryCard(
            date: 'Today',
            trips: [
              _TripDetails(
                title: 'Morning Pickup',
                time: '07:15 AM - 08:00 AM',
                status: 'Completed',
                statusColor: AppColors.success,
                icon: Icons.check_circle_rounded,
                bus: 'BLT-24',
              ),
              _TripDetails(
                title: 'Evening Drop',
                time: '02:00 PM - 02:45 PM',
                status: 'Scheduled',
                statusColor: AppColors.parent.primary,
                icon: Icons.schedule_rounded,
                bus: 'BLT-24',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _HistoryCard(
            date: 'Yesterday, 8 Jun',
            trips: [
              _TripDetails(
                title: 'Morning Pickup',
                time: '07:22 AM - 08:12 AM',
                status: 'Delayed 12 mins',
                statusColor: AppColors.warning,
                icon: Icons.warning_rounded,
                bus: 'BLT-24',
              ),
              _TripDetails(
                title: 'Evening Drop',
                time: '02:00 PM - 02:35 PM',
                status: 'Completed early',
                statusColor: AppColors.primary,
                icon: Icons.bolt_rounded,
                bus: 'BLT-24',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _MonthHeader('May 2026'),
          const SizedBox(height: 14),
          _HistoryCard(
            date: 'Friday, 5 Jun',
            trips: [
              _TripDetails(
                title: 'Morning Pickup',
                time: '07:10 AM - 07:55 AM',
                status: 'Completed',
                statusColor: AppColors.success,
                icon: Icons.check_circle_rounded,
                bus: 'BLT-24',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.date,
    required this.trips,
  });

  final String date;
  final List<_TripDetails> trips;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trips.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => trips[index],
          ),
        ],
      ),
    );
  }
}

class _TripDetails extends StatelessWidget {
  const _TripDetails({
    required this.title,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.bus,
  });

  final String title;
  final String time;
  final String status;
  final Color statusColor;
  final IconData icon;
  final String bus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bus,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
