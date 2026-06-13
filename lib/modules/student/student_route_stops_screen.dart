import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';

class StudentRouteStopsScreen extends StatefulWidget {
  const StudentRouteStopsScreen({super.key});

  @override
  State<StudentRouteStopsScreen> createState() =>
      _StudentRouteStopsScreenState();
}

class _StudentRouteStopsScreenState extends State<StudentRouteStopsScreen> {
  final List<_StopData> _stops = const [
    _StopData(
      name: 'School Gate',
      area: 'City Grammar School',
      time: '06:42 AM',
      status: _StopStatus.completed,
      studentCount: 0,
    ),
    _StopData(
      name: 'Gulshan Pickup',
      area: 'Gulshan-e-Iqbal, Karachi',
      time: '07:10 AM',
      status: _StopStatus.active,
      studentCount: 4,
    ),
    _StopData(
      name: 'Federal B Area',
      area: 'Block 17, FB Area',
      time: '07:22 AM',
      status: _StopStatus.pending,
      studentCount: 3,
    ),
    _StopData(
      name: 'Gulistan-e-Johar',
      area: 'Block 14, Johar',
      time: '07:32 AM',
      status: _StopStatus.pending,
      studentCount: 5,
    ),
    _StopData(
      name: 'Nazimabad',
      area: 'No. 5, Nazimabad',
      time: '07:44 AM',
      status: _StopStatus.pending,
      studentCount: 2,
    ),
    _StopData(
      name: 'North Nazimabad',
      area: 'Block H, North Nazimabad',
      time: '07:55 AM',
      status: _StopStatus.pending,
      studentCount: 6,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            title: const Text(
              'Route Stops',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: scheme.outlineVariant),
            ),
          ),

          // ── Route Summary Header ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF003D44), const Color(0xFF004D55)]
                            : [
                                const Color(0xFFE8F8FA),
                                const Color(0xFFF5FBFC),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'North Campus Loop',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bus BLT-24 • ${_stops.length} stops total',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _RouteProgressBadge(
                          completed: _stops
                              .where((s) => s.status == _StopStatus.completed)
                              .length,
                          total: _stops.length,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'All Stops',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      _LegendDot(color: AppColors.success, label: 'Done'),
                      const SizedBox(width: 12),
                      _LegendDot(color: AppColors.warning, label: 'Active'),
                      const SizedBox(width: 12),
                      _LegendDot(
                        color: const Color(0xFFBDBDBD),
                        label: 'Pending',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Stops List ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final stop = _stops[index];
                final isLast = index == _stops.length - 1;
                final isMyStop = stop.name == 'Gulshan Pickup';

                return _StopCard(
                  stop: stop,
                  index: index,
                  isLast: isLast,
                  isMyStop: isMyStop,
                );
              }, childCount: _stops.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.index,
    required this.isLast,
    required this.isMyStop,
  });

  final _StopData stop;
  final int index;
  final bool isLast;
  final bool isMyStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (stop.status) {
      case _StopStatus.completed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Done';
        break;
      case _StopStatus.active:
        statusColor = AppColors.warning;
        statusIcon = Icons.radio_button_checked_rounded;
        statusLabel = 'Active';
        break;
      case _StopStatus.pending:
        statusColor = scheme.onSurfaceVariant;
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Pending';
        break;
    }

    final isActive = stop.status == _StopStatus.active;
    final isDone = stop.status == _StopStatus.completed;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Icon(statusIcon, color: statusColor, size: 26),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDone
                          ? AppColors.success.withValues(alpha: 0.3)
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),

          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                            ? const Color(0xFF3D2200)
                            : const Color(0xFFFFF3E0))
                      : isDone
                      ? (isDark
                            ? const Color(0xFF0D2A1A)
                            : const Color(0xFFF0FBF4))
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? AppColors.warning.withValues(alpha: 0.4)
                        : isDone
                        ? AppColors.success.withValues(alpha: 0.25)
                        : scheme.outlineVariant,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                stop.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDone
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (isMyStop) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'My Stop',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stop.area,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.people_rounded,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${stop.studentCount} students',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          stop.time,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isActive
                                ? AppColors.warning
                                : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
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
}

class _RouteProgressBadge extends StatelessWidget {
  const _RouteProgressBadge({
    required this.completed,
    required this.total,
    required this.color,
  });

  final int completed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: completed / total,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
                strokeWidth: 5,
              ),
              Center(
                child: Text(
                  '$completed/$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Stops',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Data classes
enum _StopStatus { completed, active, pending }

class _StopData {
  const _StopData({
    required this.name,
    required this.area,
    required this.time,
    required this.status,
    required this.studentCount,
  });

  final String name;
  final String area;
  final String time;
  final _StopStatus status;
  final int studentCount;
}
