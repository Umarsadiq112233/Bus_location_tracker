import 'dart:math' as math;
import 'package:bus_location_tracker/app/theme/app_colors.dart';

import 'package:bus_location_tracker/features/tracker/presentation/painters/fleet_painters.dart';
import 'package:flutter/material.dart';

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({super.key});

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _selectedIndex = 0;

  static const _destinations = [
    _Destination('Home', Icons.dashboard_rounded),
    _Destination('Track', Icons.location_on_rounded),
    _Destination('Routes', Icons.alt_route_rounded),
    _Destination('Admin', Icons.admin_panel_settings_rounded),
    _Destination('Profile', Icons.person_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 920;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isWide ? 24 : 16,
        title: const _BrandLockup(),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.84,
              minWidth: 92,
              onDestinationSelected: _changeTab,
              destinations: [
                for (final item in _destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _AnimatedPage(
                key: ValueKey(_selectedIndex),
                child: _buildPage(_selectedIndex),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _changeTab,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => DashboardPage(animation: _controller),
      1 => LiveTrackingPage(animation: _controller),
      2 => const RoutesPage(),
      3 => const AdminPage(),
      _ => const ProfilePage(),
    };
  }

  void _changeTab(int index) {
    setState(() => _selectedIndex = index);
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      children: [
        _HeroHeader(animation: animation),
        const _SectionTitle(
          title: 'Today at a glance',
          action: 'Karachi Campus',
        ),
        const _MetricGrid(),
        _ResponsiveGrid(
          minTileWidth: 330,
          children: [
            const ParentDashboardCard(),
            const DriverDashboardCard(),
            const AuthPreviewCard(),
          ],
        ),
        const _SectionTitle(title: 'Assigned bus'),
        const BusDetailsPanel(),
      ],
    );
  }
}

class LiveTrackingPage extends StatelessWidget {
  const LiveTrackingPage({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _PageScaffold(
      children: [
        _SectionTitle(
          title: 'Live tracking',
          action: 'Auto refresh 5s',
          icon: Icons.radar_rounded,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 940;

            final sidePanel = Column(
              children: [
                _StatusCard(
                  icon: Icons.directions_bus_filled_rounded,
                  title: 'Bus BLT-24',
                  subtitle: 'Near Gulshan pickup point',
                  trailing: '12 min',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  icon: Icons.speed_rounded,
                  title: 'Current speed',
                  subtitle: 'Smooth route movement',
                  trailing: '42 km/h',
                  color: AppColors.warning,
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Emergency channel',
                  subtitle: 'Driver SOS and parent alerts ready',
                  trailing: 'Armed',
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                const PickupTimeline(),
              ],
            );

            if (!isWide) {
              return Column(
                children: [
                  _MapCard(animation: animation),
                  const SizedBox(height: 16),
                  sidePanel,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _MapCard(animation: animation)),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: sidePanel),
              ],
            );
          },
        ),
      ],
    );
  }
}

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      children: const [
        _SectionTitle(
          title: 'Routes',
          action: '4 active',
          icon: Icons.alt_route_rounded,
        ),
        _ResponsiveGrid(
          minTileWidth: 300,
          children: [
            RouteCard(
              name: 'North Campus Loop',
              stops: '8 stops',
              time: '06:40 - 07:35',
              progress: .76,
            ),
            RouteCard(
              name: 'Gulshan Express',
              stops: '6 stops',
              time: '07:10 - 08:00',
              progress: .52,
            ),
            RouteCard(
              name: 'Johar Evening',
              stops: '10 stops',
              time: '13:15 - 14:20',
              progress: .24,
            ),
          ],
        ),
        _SectionTitle(title: 'Trip history'),
        TripHistoryPanel(),
      ],
    );
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      children: const [
        _SectionTitle(
          title: 'Admin control center',
          action: 'Static phase',
          icon: Icons.admin_panel_settings_rounded,
        ),
        _ResponsiveGrid(
          minTileWidth: 230,
          children: [
            AdminTile(
              icon: Icons.directions_bus_rounded,
              title: 'Buses',
              value: '18',
              detail: '16 active now',
            ),
            AdminTile(
              icon: Icons.badge_rounded,
              title: 'Drivers',
              value: '22',
              detail: '2 on standby',
            ),
            AdminTile(
              icon: Icons.school_rounded,
              title: 'Students',
              value: '1,248',
              detail: '987 assigned',
            ),
            AdminTile(
              icon: Icons.notifications_active_rounded,
              title: 'Alerts',
              value: '7',
              detail: '3 need review',
            ),
          ],
        ),
        _SectionTitle(title: 'Management shortcuts'),
        ManagementPanel(),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      children: const [
        _SectionTitle(
          title: 'Profile',
          action: 'Parent account',
          icon: Icons.person_rounded,
        ),
        ProfileHeader(),
        _ResponsiveGrid(
          minTileWidth: 310,
          children: [
            ProfileSettingTile(
              icon: Icons.home_rounded,
              title: 'Home geofence',
              detail: 'Block 13-D, Karachi',
            ),
            ProfileSettingTile(
              icon: Icons.notifications_rounded,
              title: 'Arrival notifications',
              detail: 'Bus near home, bus arrived, delays',
            ),
            ProfileSettingTile(
              icon: Icons.security_rounded,
              title: 'Safety contacts',
              detail: 'School admin, driver, emergency desk',
            ),
          ],
        ),
      ],
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in children) ...[
                  child,
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 760;

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusPill(
                icon: Icons.verified_rounded,
                label: 'Phase 1 static UI',
                color: scheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Track every school bus with clarity and confidence.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A polished dashboard for parents, drivers, and admins with live-map previews, ETA cards, emergency states, routes, and profile controls.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: .78),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Trip'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('View Routes'),
                  ),
                ],
              ),
            ],
          );
          final scene = SizedBox(
            height: 230,
            child: _MiniFleetScene(animation: animation),
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 24), scene],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: copy),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: scene),
            ],
          );
        },
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context) {
    return const _ResponsiveGrid(
      minTileWidth: 210,
      children: [
        MetricCard(
          icon: Icons.directions_bus_filled_rounded,
          label: 'Active buses',
          value: '16',
          trend: '+4 moving',
        ),
        MetricCard(
          icon: Icons.schedule_rounded,
          label: 'Avg ETA',
          value: '11m',
          trend: '2m faster',
        ),
        MetricCard(
          icon: Icons.people_alt_rounded,
          label: 'Students onboard',
          value: '342',
          trend: '98% synced',
        ),
        MetricCard(
          icon: Icons.health_and_safety_rounded,
          label: 'Safety status',
          value: 'Safe',
          trend: 'No SOS',
        ),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, this.minTileWidth = 280});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = math.max(1, constraints.maxWidth ~/ minTileWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 220,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              child: Icon(icon),
            ),
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 5),
            Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  icon: Icons.trending_up_rounded,
                  label: trend,
                  color: scheme.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ParentDashboardCard extends StatelessWidget {
  const ParentDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _RoleCard(
      icon: Icons.family_restroom_rounded,
      title: 'Parent dashboard',
      subtitle: 'Live ETA, assigned bus, alerts, and trip history.',
      chips: const ['ETA 12m', 'Bus BLT-24', 'Safe'],
    );
  }
}

class DriverDashboardCard extends StatelessWidget {
  const DriverDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _RoleCard(
      icon: Icons.drive_eta_rounded,
      title: 'Driver dashboard',
      subtitle: 'Start trip, end trip, route state, and SOS access.',
      chips: const ['Trip active', 'GPS ready', 'SOS'],
    );
  }
}

class AuthPreviewCard extends StatelessWidget {
  const AuthPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_person_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Login / Register',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: 'parent@school.edu',
                      readOnly: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_rounded),
                        labelText: 'Email',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: 'secure trip access',
                      readOnly: true,
                      obscureText: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.key_rounded),
                        labelText: 'Password',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  Chip(visualDensity: VisualDensity.compact, label: Text(chip)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: SizedBox(
        height: 520,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: RouteMapPainter(
                        colorScheme: scheme,
                        progress: animation.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: _StatusPill(
                icon: Icons.circle,
                label: 'Live GPS',
                color: AppColors.success,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _GlassPanel(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: const Icon(Icons.directions_bus_rounded),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BLT-24 is heading to Campus Gate A',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text('Next pickup: Federal B Area'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '2.8 km',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFleetScene extends StatelessWidget {
  const _MiniFleetScene({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: FleetPainter(
            colorScheme: Theme.of(context).colorScheme,
            progress: animation.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class BusDetailsPanel extends StatelessWidget {
  const BusDetailsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 18,
          runSpacing: 18,
          alignment: WrapAlignment.spaceBetween,
          children: const [
            _DetailItem(Icons.confirmation_number_rounded, 'Bus ID', 'BLT-24'),
            _DetailItem(Icons.person_rounded, 'Driver', 'Ahmed Raza'),
            _DetailItem(Icons.route_rounded, 'Route', 'North Campus Loop'),
            _DetailItem(Icons.battery_charging_full_rounded, 'GPS unit', '96%'),
            _DetailItem(Icons.wifi_tethering_rounded, 'Signal', 'Strong'),
          ],
        ),
      ),
    );
  }
}

class PickupTimeline extends StatelessWidget {
  const PickupTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final stops = [
      ('School Gate', 'Departed 06:42'),
      ('Gulshan Pickup', 'Arriving 06:58'),
      ('Federal B Area', 'ETA 07:10'),
      ('Campus Gate A', 'ETA 07:28'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pickup timeline',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < stops.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 15, child: Text('${i + 1}')),
                title: Text(stops[i].$1),
                subtitle: Text(stops[i].$2),
                trailing: i == 1
                    ? const Icon(Icons.navigation_rounded)
                    : const Icon(Icons.check_circle_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.name,
    required this.stops,
    required this.time,
    required this.progress,
  });

  final String name;
  final String stops;
  final String time;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.route_rounded, color: scheme.primary),
            const Spacer(),
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text('$stops  |  $time'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class TripHistoryPanel extends StatelessWidget {
  const TripHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: const [
            _HistoryRow('Morning trip', 'Completed', '34 students', '07:33'),
            Divider(height: 1),
            _HistoryRow('Midday pickup', 'Delayed', '18 students', '12:14'),
            Divider(height: 1),
            _HistoryRow('Evening drop', 'Scheduled', '41 students', '14:20'),
          ],
        ),
      ),
    );
  }
}

class AdminTile extends StatelessWidget {
  const AdminTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(detail),
          ],
        ),
      ),
    );
  }
}

class ManagementPanel extends StatelessWidget {
  const ManagementPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_road_rounded, 'Create route'),
      (Icons.assignment_ind_rounded, 'Assign driver'),
      (Icons.directions_bus_rounded, 'Assign bus'),
      (Icons.summarize_rounded, 'Generate report'),
      (Icons.campaign_rounded, 'Send notification'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: Icon(action.$1),
                label: Text(action.$2),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.person_rounded, size: 38),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mrs. Sara Khan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text('Parent of Zain Khan - Grade 7'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSettingTile extends StatelessWidget {
  const ProfileSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .16),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          trailing,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(this.trip, this.status, this.students, this.time);

  final String trip;
  final String status;
  final String students;
  final String time;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history_rounded),
      title: Text(trip),
      subtitle: Text(students),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(time),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.icon});

  final String title;
  final String? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.directions_bus_filled_rounded,
            color: scheme.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BLT',
              style: TextStyle(fontWeight: FontWeight.w900, height: 1),
            ),
            Text(
              'Bus Location Tracker',
              style: TextStyle(fontSize: 12, height: 1.1),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimatedPage extends StatelessWidget {
  const _AnimatedPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}
