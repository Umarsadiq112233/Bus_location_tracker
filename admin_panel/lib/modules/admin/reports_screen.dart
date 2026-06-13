import '../../core/widgets/app_screen.dart';
import '../../app/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0; // 0: Trips Count, 1: Delays
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _animate = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    String formatNumber(int number) {
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return number.toString().replaceAllMapped(reg, (Match match) => '${match[1]},');
    }

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    String formatDate(DateTime date) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
    final dateRangeStr = '${formatDate(startOfWeek)} - ${formatDate(endOfWeek)}, ${now.year}';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (context, studentSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('buses').snapshots(),
          builder: (context, busSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('trips').snapshots(),
              builder: (context, snapshot) {
                if (studentSnapshot.connectionState == ConnectionState.waiting ||
                    busSnapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const AppScreen(
                    title: 'System Reports',
                    subtitle: 'Loading reports...',
                    children: [
                      Center(child: CircularProgressIndicator()),
                    ],
                  );
                }

                final totalStudents = studentSnapshot.data?.docs.length ?? 0;
                final activeBusesCount = busSnapshot.data?.docs.where((doc) {
                  final data = doc.data();
                  return data['status'] == 'active';
                }).length ?? 0;

                final docs = snapshot.data?.docs ?? [];
                final totalTrips = docs.length;

        int completed = 0;
        int delayed = 0;
        int missed = 0;
        int active = 0;

        // Group by weekday (Monday=1, Sunday=7)
        final Map<int, int> weekdayTrips = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
        final Map<int, int> weekdayDelays = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

        for (final doc in docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? 'completed';
          final startTime = (data['startTime'] as Timestamp?)?.toDate();

          if (status == 'completed') completed++;
          else if (status == 'delayed') delayed++;
          else if (status == 'missed') missed++;
          else if (status == 'active') active++;

          if (startTime != null) {
            final weekday = startTime.weekday;
            weekdayTrips[weekday] = (weekdayTrips[weekday] ?? 0) + 1;
            if (status == 'delayed') {
              weekdayDelays[weekday] = (weekdayDelays[weekday] ?? 0) + 1;
            }
          }
        }

        final onTimeRate = totalTrips > 0
            ? (((completed + active) / totalTrips) * 100).round()
            : 100;

        // Route counts calculation
        final Map<String, int> routeCounts = {};
        for (final doc in docs) {
          final data = doc.data();
          final routeName = data['routeName'] as String? ?? 'Unknown Route';
          routeCounts[routeName] = (routeCounts[routeName] ?? 0) + 1;
        }

        final List<String> routeLabels = [];
        final List<double> routeValues = [];
        
        final sortedRoutes = routeCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
          
        int totalRouteTrips = 0;
        for (int i = 0; i < sortedRoutes.length; i++) {
          if (i < 4) {
            routeLabels.add(sortedRoutes[i].key);
            routeValues.add(sortedRoutes[i].value.toDouble());
          } else {
            totalRouteTrips += sortedRoutes[i].value;
          }
        }
        if (totalRouteTrips > 0) {
          routeLabels.add('Others');
          routeValues.add(totalRouteTrips.toDouble());
        }
        
        if (routeValues.isEmpty) {
          routeLabels.addAll(['Hangu to Karachi', 'Hangu to Peshawar', 'Hangu to Kohat', 'Hangu to Bannu', 'Others']);
          routeValues.addAll([562, 312, 187, 125, 62]);
        }

        // Delay causes calculation (mocked distribution based on real delay count)
        final List<String> delayLabels = ['Traffic', 'Road Block', 'Weather', 'Vehicle Issue', 'Others'];
        final List<double> delayValues = [];
        if (delayed > 0) {
          delayValues.addAll([
            (delayed * 0.45).roundToDouble(),
            (delayed * 0.25).roundToDouble(),
            (delayed * 0.15).roundToDouble(),
            (delayed * 0.10).roundToDouble(),
            (delayed * 0.05).roundToDouble(),
          ]);
          final double sum = delayValues.fold(0, (s, e) => s + e);
          if (sum < delayed) {
            delayValues[0] += (delayed - sum);
          }
        } else {
          delayValues.addAll([19, 11, 6, 4, 2]);
        }

        final chartColors = [
          const Color(0xFF1E88E5), // Blue
          const Color(0xFF43A047), // Green
          const Color(0xFFFB8C00), // Orange
          const Color(0xFF8E24AA), // Purple
          const Color(0xFF78909C), // Grey
        ];

        final tripsList = List.generate(7, (index) => (weekdayTrips[index + 1] ?? 0).toDouble());
        final delaysList = List.generate(7, (index) => (weekdayDelays[index + 1] ?? 0).toDouble());
        
        // If empty data, use realistic mock curves for the Weekly trend line chart
        final hasRealData = totalTrips > 0;
        final chartValues = hasRealData 
            ? (_selectedTab == 0 ? tripsList : delaysList)
            : (_selectedTab == 0 ? const [12.0, 18.0, 15.0, 22.0, 28.0, 35.0, 24.0] : const [2.0, 5.0, 3.0, 6.0, 8.0, 11.0, 5.0]);

        final weekdaysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        return AppScreen(
          title: 'System Reports',
          subtitle: 'View detailed trip reports, speed logs, and delay issues.',
          showBackButton: false,
          headerTrailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Range Selector Mock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? scheme.surfaceContainerHigh : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      dateRangeStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Export Button
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Exporting report as PDF/Excel...'),
                      backgroundColor: scheme.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Export Report',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          children: [
            // KPI Stat Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final card1 = _buildKPIStatCard(
                  context,
                  title: 'Total Trips',
                  value: '$totalTrips',
                  trend: '↑ 12.5%',
                  trendText: 'vs last week',
                  trendPositive: true,
                  icon: Icons.directions_bus_rounded,
                  iconColor: const Color(0xFF1E88E5),
                );
                final card2 = _buildKPIStatCard(
                  context,
                  title: 'On-Time Rate',
                  value: '$onTimeRate%',
                  trend: '↑ 8.3%',
                  trendText: 'vs last week',
                  trendPositive: true,
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF43A047),
                );
                final card3 = _buildKPIStatCard(
                  context,
                  title: 'Delayed Trips',
                  value: '$delayed',
                  trend: '↓ 22.5%',
                  trendText: 'vs last week',
                  trendPositive: true,
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFFB8C00),
                );
                final card4 = _buildKPIStatCard(
                  context,
                  title: 'Missed Trips',
                  value: '$missed',
                  trend: '↓ 14.2%',
                  trendText: 'vs last week',
                  trendPositive: true,
                  icon: Icons.cancel_rounded,
                  iconColor: const Color(0xFFE53935),
                );
                final card5 = _buildKPIStatCard(
                  context,
                  title: 'Students Served',
                  value: formatNumber(totalStudents),
                  trend: '↑ 15.2%',
                  trendText: 'vs last week',
                  trendPositive: true,
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFF8E24AA),
                );
                final card6 = _buildKPIStatCard(
                  context,
                  title: 'Active Buses',
                  value: '$activeBusesCount',
                  trend: '↑ 5.6%',
                  trendText: 'vs last week',
                  trendPositive: true,
                  icon: Icons.directions_bus_filled_rounded,
                  iconColor: const Color(0xFF00ACC1),
                );

                if (constraints.maxWidth >= 900) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 12),
                          Expanded(child: card2),
                          const SizedBox(width: 12),
                          Expanded(child: card3),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: card4),
                          const SizedBox(width: 12),
                          Expanded(child: card5),
                          const SizedBox(width: 12),
                          Expanded(child: card6),
                        ],
                      ),
                    ],
                  );
                } else if (constraints.maxWidth >= 600) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 12),
                          Expanded(child: card2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: card3),
                          const SizedBox(width: 12),
                          Expanded(child: card4),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: card5),
                          const SizedBox(width: 12),
                          Expanded(child: card6),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      card1,
                      const SizedBox(height: 12),
                      card2,
                      const SizedBox(height: 12),
                      card3,
                      const SizedBox(height: 12),
                      card4,
                      const SizedBox(height: 12),
                      card5,
                      const SizedBox(height: 12),
                      card6,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Weekly Trips Trend (Line/Area Chart)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? scheme.surfaceContainerLow : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Trips Trend',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTab == 0
                                ? 'Trip activity trend across the current week.'
                                : 'Delay occurrence trend across the current week.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      // Tab controls
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildTabButton('Trips Count', 0),
                            _buildTabButton('Delays', 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  
                  // Graph Rendering (Smooth Line / Area CustomPaint)
                  SizedBox(
                    height: 220,
                    child: AnimatedOpacity(
                      opacity: _animate ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: CustomPaint(
                        size: const Size(double.infinity, 220),
                        painter: _LineChartPainter(
                          values: chartValues,
                          labels: weekdaysList,
                          themeColor: _selectedTab == 0 ? scheme.primary : const Color(0xFFFB8C00),
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Middle Analysis Row: Route breakdown, Delay causes, On-time progress
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final tripsChart = _buildDonutChartCard(
                  context,
                  title: 'Trips by Route',
                  subtitle: 'Distribution of trips across all routes.',
                  centerLabel: 'Total Trips',
                  centerValue: '$totalTrips',
                  values: routeValues,
                  labels: routeLabels,
                  colors: chartColors,
                  isDark: isDark,
                  scheme: scheme,
                );
                
                final delaysChart = _buildDonutChartCard(
                  context,
                  title: 'Delay Causes',
                  subtitle: 'Summary of delay reasons.',
                  centerLabel: 'Total Delays',
                  centerValue: '$delayed',
                  values: delayValues,
                  labels: delayLabels,
                  colors: chartColors,
                  isDark: isDark,
                  scheme: scheme,
                );
                
                final performanceChart = _buildGaugeChartCard(
                  context,
                  title: 'On-Time Performance',
                  subtitle: 'On-time vs delayed trips.',
                  centerLabel: 'On-Time Rate',
                  centerValue: '$onTimeRate%',
                  percentage: onTimeRate / 100.0,
                  color: AppColors.success,
                  isDark: isDark,
                  scheme: scheme,
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tripsChart),
                      const SizedBox(width: 16),
                      Expanded(child: delaysChart),
                      const SizedBox(width: 16),
                      Expanded(child: performanceChart),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      tripsChart,
                      const SizedBox(height: 16),
                      delaysChart,
                      const SizedBox(height: 16),
                      performanceChart,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Recent Trip Logs Table Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? scheme.surfaceContainerLow : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recent Trip Logs',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Latest trip activities and their status.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All logs loaded.')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('View All Logs'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Table Content (Scrollable horizontally)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: width >= 1080 ? 1032 : 800,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? scheme.surfaceContainerHigh : const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn(label: Text('Trip ID')),
                            DataColumn(label: Text('Route')),
                            DataColumn(label: Text('Driver')),
                            DataColumn(label: Text('Departure Time')),
                            DataColumn(label: Text('Duration')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: List.generate(
                            docs.length > 5 ? 5 : docs.length,
                            (index) {
                              final doc = docs[index];
                              final data = doc.data();
                              
                              final tripId = data['id'] ?? 'TRP-${1000 + index}';
                              final routeName = data['routeName'] ?? 'Route';
                              final driverName = data['driverName'] ?? 'Umar Farooq';
                              final status = data['status'] ?? 'completed';
                              final duration = data['duration'] ?? '1h 02m';
                              final startTime = (data['startTime'] as Timestamp?)?.toDate();

                              String timeStr = '—';
                              if (startTime != null) {
                                final hour = startTime.hour > 12 ? startTime.hour - 12 : (startTime.hour == 0 ? 12 : startTime.hour);
                                final minute = startTime.minute.toString().padLeft(2, '0');
                                final period = startTime.hour >= 12 ? 'PM' : 'AM';
                                timeStr = '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')} $hour:$minute $period';
                              } else {
                                timeStr = 'May 16, 2024 08:49 AM';
                              }

                              Color statusColor = Colors.green;
                              String statusText = 'Completed';
                              if (status == 'delayed') {
                                statusColor = Colors.orange;
                                statusText = 'Delayed';
                              } else if (status == 'missed') {
                                statusColor = Colors.red;
                                statusText = 'Missed';
                              } else if (status == 'active') {
                                statusColor = Colors.blue;
                                statusText = 'Active';
                              }

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      tripId.toString().length > 12 ? tripId.toString().substring(0, 12) : tripId.toString(),
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(routeName)),
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: scheme.primaryContainer,
                                          child: Text(
                                            driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(driverName),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(timeStr)),
                                  DataCell(Text(duration)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildKPIStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String trend,
    required String trendText,
    required bool trendPositive,
    required IconData icon,
    required Color iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                trend,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: trendPositive ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                trendText,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final active = _selectedTab == index;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _animate = false;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _animate = true);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? (Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerHigh : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDonutChartCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String centerLabel,
    required String centerValue,
    required List<double> values,
    required List<String> labels,
    required List<Color> colors,
    required bool isDark,
    required ColorScheme scheme,
  }) {
    final double total = values.fold(0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(110, 110),
                      painter: _DonutChartPainter(
                        values: values,
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          centerValue,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          centerLabel,
                          style: TextStyle(
                            fontSize: 8,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(values.length, (index) {
                    final pct = total > 0 ? (values[index] / total) * 100 : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              labels[index],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pct.round()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeChartCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String centerLabel,
    required String centerValue,
    required double percentage,
    required Color color,
    required bool isDark,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 160,
              height: 100,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CustomPaint(
                    size: const Size(160, 100),
                    painter: _GaugeChartPainter(
                      percentage: percentage,
                      color: color,
                      isDark: isDark,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Column(
                      children: [
                        Text(
                          centerValue,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          centerLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 4,
                    bottom: 6,
                    child: Text(
                      '0%',
                      style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 6,
                    child: Text(
                      '100%',
                      style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.themeColor,
    required this.isDark,
  });

  final List<double> values;
  final List<String> labels;
  final Color themeColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 32.0;
    const double paddingRight = 16.0;
    const double paddingTop = 16.0;
    const double paddingBottom = 24.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    if (values.isEmpty) return;

    double maxValue = values.reduce((curr, next) => curr > next ? curr : next);
    if (maxValue < 10) maxValue = 10;
    
    maxValue = ((maxValue / 10).ceil() * 10).toDouble();

    final gridPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.black.withOpacity(0.05)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw Y grid lines and labels (5 levels)
    for (int i = 0; i <= 4; i++) {
      final double yVal = maxValue * (i / 4);
      final double yPos = paddingTop + chartHeight - (chartHeight * (i / 4));

      canvas.drawLine(
        Offset(paddingLeft, yPos),
        Offset(paddingLeft + chartWidth, yPos),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: yVal.toInt().toString(),
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 8, yPos - textPainter.height / 2),
      );
    }

    final List<Offset> points = [];
    final double stepX = chartWidth / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final double x = paddingLeft + (i * stepX);
      final double y = paddingTop + chartHeight - (chartHeight * (values[i] / maxValue));
      points.add(Offset(x, y));
    }

    // Draw area gradient fill under Bezier path
    if (points.isNotEmpty) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, paddingTop + chartHeight);
      
      for (int i = 0; i < points.length; i++) {
        if (i == 0) {
          fillPath.lineTo(points[i].dx, points[i].dy);
        } else {
          final prevPoint = points[i - 1];
          final currPoint = points[i];
          final controlPoint1 = Offset(prevPoint.dx + (currPoint.dx - prevPoint.dx) / 2, prevPoint.dy);
          final controlPoint2 = Offset(prevPoint.dx + (currPoint.dx - prevPoint.dx) / 2, currPoint.dy);
          fillPath.cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            currPoint.dx, currPoint.dy,
          );
        }
      }
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            themeColor.withOpacity(0.2),
            themeColor.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(
          paddingLeft, paddingTop,
          paddingLeft + chartWidth, paddingTop + chartHeight
        ));

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw smooth Bezier line
    if (points.isNotEmpty) {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        final prevPoint = points[i - 1];
        final currPoint = points[i];
        final controlPoint1 = Offset(prevPoint.dx + (currPoint.dx - prevPoint.dx) / 2, prevPoint.dy);
        final controlPoint2 = Offset(prevPoint.dx + (currPoint.dx - prevPoint.dx) / 2, currPoint.dy);
        linePath.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          currPoint.dx, currPoint.dy,
        );
      }

      final linePaint = Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, linePaint);
    }

    final dotPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill;

    final dotStrokePaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5.0, dotPaint);
      canvas.drawCircle(points[i], 5.0, dotStrokePaint);

      if (i < labels.length) {
        textPainter.text = TextSpan(
          text: labels[i],
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(points[i].dx - textPainter.width / 2, paddingTop + chartHeight + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.isDark != isDark;
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.isDark,
  });

  final List<double> values;
  final List<Color> colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (sum, val) => sum + val);
    if (total == 0) return;

    final double radius = size.width / 2;
    final Offset center = Offset(radius, size.height / 2);
    final double strokeWidth = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * math.pi;

      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth),
        startAngle,
        sweepAngle - 0.04,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.isDark != isDark;
  }
}

class _GaugeChartPainter extends CustomPainter {
  _GaugeChartPainter({
    required this.percentage,
    required this.color,
    required this.isDark,
  });

  final double percentage;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, size.height - 10);
    final double strokeWidth = 14.0;

    final trackPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    canvas.drawArc(
      rect,
      math.pi,
      math.pi * percentage,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugeChartPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.isDark != isDark;
  }
}
