import 'dart:math' as math;
import '../../app/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';
import 'manage_buses_screen.dart';
import 'manage_routes_screen.dart';
import 'manage_drivers_screen.dart';
import 'manage_students_parents_screen.dart';
import 'admin_live_tracking_screen.dart';
import 'reports_screen.dart';
import 'admin_profile_screen.dart';
import 'emergency_alerts_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  static AdminDashboardScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<AdminDashboardScreenState>();
  }

  static bool navigateToTab(BuildContext context, String routeName) {
    final state = context.findAncestorStateOfType<AdminDashboardScreenState>();
    if (state != null && MediaQuery.of(context).size.width >= 900) {
      final index = state._mapRouteToIndex(routeName);
      if (index != null) {
        final parentTab = routeName == '/manage-parents' ? 1 : 0;
        state.setIndex(index, studentParentTab: parentTab);
        return true;
      }
    }
    return false;
  }

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  int defaultStudentParentTab = 0;
  final AuthService _authService = AuthService();

  UserModel? _adminModel;
  bool _loadingAdmin = true;

  final List<Widget> _pages = const [
    _AdminHomeTab(),             // 0
    ManageBusesScreen(),         // 1
    ManageRoutesScreen(),        // 2
    ManageDriversScreen(),       // 3
    ManageStudentsParentsScreen(),// 4
    AdminLiveTrackingScreen(),   // 5
    ReportsScreen(),             // 6
    AdminProfileScreen(),        // 7
    EmergencyAlertsScreen(),     // 8
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final data = await _authService.getUserData(currentUser.uid);
      if (mounted) {
        setState(() {
          _adminModel = data;
          _loadingAdmin = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingAdmin = false);
    }
  }

  void setIndex(int index, {int studentParentTab = 0}) {
    setState(() {
      _currentIndex = index;
      defaultStudentParentTab = studentParentTab;
    });
  }

  int? _mapRouteToIndex(String routeName) {
    return switch (routeName) {
      '/dashboard' => 0,
      '/manage-buses' => 1,
      '/manage-routes' => 2,
      '/manage-drivers' => 3,
      '/manage-students' => 4,
      '/manage-parents' => 4,
      '/admin-live-tracking' => 5,
      '/reports' => 6,
      '/profile' => 7,
      '/emergency-alerts' => 8,
      _ => null,
    };
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalEmergencyBanner(BuildContext context) {
    if (_currentIndex == 8) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        final firstAlert = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final type = firstAlert['type'] ?? 'Emergency';
        final busNum = firstAlert['busNumber'] ?? 'Unknown';

        return Material(
          color: AppColors.danger,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      count == 1
                          ? '🚨 Active SOS: $type reported on Bus $busNum!'
                          : '🚨 Active SOS: $count drivers have reported emergencies!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setIndex(8),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = size.width >= 900;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              currentIndex: _currentIndex,
              onSelect: setIndex,
              onLogout: _handleLogout,
              adminModel: _adminModel,
              loading: _loadingAdmin,
            ),
            VerticalDivider(
              width: 1,
              thickness: 0.8,
              color: scheme.outlineVariant,
            ),
            Expanded(
              child: Column(
                children: [
                  _buildGlobalEmergencyBanner(context),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _pages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile/Tablet
    return Scaffold(
      body: Column(
        children: [
          _buildGlobalEmergencyBanner(context),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.directions_bus_rounded,
                  label: 'Buses',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.alt_route_rounded,
                  label: 'Routes',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.gpp_maybe_rounded,
                  label: 'SOS Alerts',
                  isSelected: _currentIndex == 8,
                  onTap: () => setState(() => _currentIndex = 8),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 7,
                  onTap: () => setState(() => _currentIndex = 7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.onSelect,
    required this.onLogout,
    required this.adminModel,
    required this.loading,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final UserModel? adminModel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = adminModel?.name ?? 'Admin User';
    final email = adminModel?.email ?? 'admin@school.edu';
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'AD';

    return Container(
      width: 280,
      color: isDark ? const Color(0xFF0F172A) : scheme.surfaceContainerLow,
      child: Column(
        children: [
          // App Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF512DA8), AppColors.admin.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'BLT Admin Portal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Active Profile Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? scheme.surfaceContainerHigh : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.admin.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Menu Items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _SidebarItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: currentIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _SidebarItem(
                    icon: Icons.directions_bus_rounded,
                    label: 'Buses',
                    isSelected: currentIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  _SidebarItem(
                    icon: Icons.alt_route_rounded,
                    label: 'Routes',
                    isSelected: currentIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                  _SidebarItem(
                    icon: Icons.badge_rounded,
                    label: 'Drivers',
                    isSelected: currentIndex == 3,
                    onTap: () => onSelect(3),
                  ),
                  _SidebarItem(
                    icon: Icons.people_rounded,
                    label: 'Students & Parents',
                    isSelected: currentIndex == 4,
                    onTap: () => onSelect(4),
                  ),
                  _SidebarItem(
                    icon: Icons.map_rounded,
                    label: 'Live Tracking',
                    isSelected: currentIndex == 5,
                    onTap: () => onSelect(5),
                  ),
                  _SidebarItem(
                    icon: Icons.gpp_maybe_rounded,
                    label: 'Emergency Alerts',
                    isSelected: currentIndex == 8,
                    onTap: () => onSelect(8),
                    badge: _buildEmergencyBadge(),
                  ),
                  _SidebarItem(
                    icon: Icons.assessment_rounded,
                    label: 'Reports',
                    isSelected: currentIndex == 6,
                    onTap: () => onSelect(6),
                  ),
                  _SidebarItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: currentIndex == 7,
                    onTap: () => onSelect(7),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              isSelected: false,
              onTap: onLogout,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDestructive = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? badge;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = widget.isDestructive
        ? scheme.error
        : AppColors.admin.primary;

    final textColor = widget.isSelected
        ? activeColor
        : (_isHovered
            ? (widget.isDestructive
                ? scheme.error
                : (isDark ? Colors.white : activeColor.withValues(alpha: 0.85)))
            : scheme.onSurfaceVariant);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? activeColor.withValues(alpha: 0.12)
                : (_isHovered
                    ? activeColor.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? activeColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Left indicator line
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? activeColor
                      : (_isHovered && !widget.isDestructive
                          ? activeColor.withValues(alpha: 0.4)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                widget.icon,
                size: 20,
                color: textColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected || _isHovered
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (widget.badge != null) widget.badge!,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.admin.primary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? color : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHomeTab extends StatefulWidget {
  const _AdminHomeTab();

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab>
    with SingleTickerProviderStateMixin {
  static void _dummyOnTap() {}
  late final AnimationController _entryController;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;
  static const _sectionCount = 5;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimations = List.generate(_sectionCount, (index) {
      final start = index * 0.15;
      final end = (index * 0.15) + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(start, math.min(end, 1.0), curve: Curves.easeOut),
        ),
      );
    });

    _slideAnimations = List.generate(_sectionCount, (index) {
      final start = index * 0.15;
      final end = (index * 0.15) + 0.4;
      return Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(start, math.min(end, 1.0), curve: Curves.easeOutCubic),
        ),
      );
    });

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, String routeName) {
    if (!AdminDashboardScreen.navigateToTab(context, routeName)) {
      Navigator.pushNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _AdminSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                
                // Section 0: Stats Grid
                AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) => FadeTransition(
                    opacity: _fadeAnimations[0],
                    child: SlideTransition(
                      position: _slideAnimations[0],
                      child: child,
                    ),
                  ),
                  child: const _StatsGrid(),
                ),
                
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (60% width)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Real-time Map Preview'),
                            const SizedBox(height: 12),
                            
                            // Section 1: Map Preview
                            AnimatedBuilder(
                              animation: _entryController,
                              builder: (context, child) => FadeTransition(
                                opacity: _fadeAnimations[1],
                                child: SlideTransition(
                                  position: _slideAnimations[1],
                                  child: child,
                                ),
                              ),
                              child: const LiveDashboardMapPanel(),
                            ),
                            
                            const SizedBox(height: 24),
                            const _SectionTitle('Recent Trips'),
                            const SizedBox(height: 12),
                            
                            // Section 2: Recent Trips list
                            AnimatedBuilder(
                              animation: _entryController,
                              builder: (context, child) => FadeTransition(
                                opacity: _fadeAnimations[2],
                                child: SlideTransition(
                                  position: _slideAnimations[2],
                                  child: child,
                                ),
                              ),
                              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance.collection('trips').snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Column(
                                      children: [
                                        _OverviewCard(
                                          icon: Icons.history_rounded,
                                          iconColor: Color(0xFF7B2FBE),
                                          title: 'Loading trips...',
                                          subtitle: 'Retrieving latest bus activity...',
                                          actionText: 'Loading',
                                          onTap: _dummyOnTap,
                                        ),
                                      ],
                                    );
                                  }

                                  final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                                    snapshot.data?.docs ?? [],
                                  );

                                  if (docs.isNotEmpty) {
                                    docs.sort((a, b) {
                                      final aTime = (a.data()['startTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                                      final bTime = (b.data()['startTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                                      return bTime.compareTo(aTime);
                                    });
                                  }

                                  if (docs.isEmpty) {
                                    return Column(
                                      children: [
                                        _OverviewCard(
                                          icon: Icons.history_rounded,
                                          iconColor: const Color(0xFF7B2FBE),
                                          title: 'No recent trips',
                                          subtitle: 'No school bus trips have been recorded yet.',
                                          actionText: 'View Reports',
                                          onTap: () => _navigate(context, '/reports'),
                                        ),
                                      ],
                                    );
                                  }

                                  final displayDocs = docs.take(3).toList();

                                  return Column(
                                    children: displayDocs.map((doc) {
                                      final data = doc.data();
                                      final busNumber = data['busNumber'] ?? 'Bus';
                                      final routeName = data['routeName'] ?? 'Route';
                                      final status = data['status'] ?? 'completed';
                                      final startTime = (data['startTime'] as Timestamp?)?.toDate();
                                      final duration = data['duration'] ?? '';

                                      String timeStr = '';
                                      if (startTime != null) {
                                        final hour = startTime.hour > 12 ? startTime.hour - 12 : (startTime.hour == 0 ? 12 : startTime.hour);
                                        final minute = startTime.minute.toString().padLeft(2, '0');
                                        final period = startTime.hour >= 12 ? 'PM' : 'AM';
                                        timeStr = ' at $hour:$minute $period';
                                      }

                                      String title = '';
                                      String subtitle = '';
                                      Color iconColor = const Color(0xFF7B2FBE);
                                      IconData icon = Icons.history_rounded;

                                      if (status == 'active') {
                                        title = 'Bus $busNumber is on the way';
                                        subtitle = 'Route: $routeName. Currently active on trip$timeStr.';
                                        iconColor = AppColors.primary;
                                        icon = Icons.directions_bus_rounded;
                                      } else if (status == 'delayed') {
                                        title = 'Delay Alert (Bus $busNumber)';
                                        subtitle = 'Bus $busNumber running late on route $routeName${duration.isNotEmpty ? ' ($duration duration)' : ''}.';
                                        iconColor = AppColors.warning;
                                        icon = Icons.warning_amber_rounded;
                                      } else if (status == 'missed') {
                                        title = 'Trip Missed (Bus $busNumber)';
                                        subtitle = 'Bus $busNumber missed its scheduled trip on route $routeName.';
                                        iconColor = AppColors.danger;
                                        icon = Icons.cancel_rounded;
                                      } else {
                                        title = 'Trip Completed (Bus $busNumber)';
                                        subtitle = 'Route: $routeName. Trip successfully completed$timeStr${duration.isNotEmpty ? ' in $duration' : ''}.';
                                        iconColor = AppColors.success;
                                        icon = Icons.check_circle_rounded;
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _OverviewCard(
                                          icon: icon,
                                          iconColor: iconColor,
                                          title: title,
                                          subtitle: subtitle,
                                          actionText: status == 'active' ? 'Track' : 'View',
                                          isAlert: status == 'delayed' || status == 'missed',
                                          onTap: () {
                                            if (status == 'active') {
                                              _navigate(context, '/admin-live-tracking');
                                            } else {
                                              _navigate(context, '/reports');
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column (40% width)
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('System Status'),
                            const SizedBox(height: 12),
                            
                            // Section 3: System Status
                            AnimatedBuilder(
                              animation: _entryController,
                              builder: (context, child) => FadeTransition(
                                opacity: _fadeAnimations[3],
                                child: SlideTransition(
                                  position: _slideAnimations[3],
                                  child: child,
                                ),
                              ),
                              child: Column(
                                children: [
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('emergency_alerts')
                                        .where('status', isEqualTo: 'active')
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      final activeDocs = snapshot.data?.docs ?? [];
                                      final count = activeDocs.length;
                                      final hasAlerts = count > 0;
                                      
                                      String subtitle = 'No active emergency alerts at the moment.';
                                      if (count == 1) {
                                        final type = (activeDocs.first.data() as Map<String, dynamic>)['type'] ?? 'Emergency';
                                        final driver = (activeDocs.first.data() as Map<String, dynamic>)['driverName'] ?? 'Driver';
                                        subtitle = '1 active alert: $type reported by $driver.';
                                      } else if (count > 1) {
                                        subtitle = '$count active emergency alerts require attention!';
                                      }
                                      
                                      return _OverviewCard(
                                        icon: Icons.warning_rounded,
                                        iconColor: hasAlerts ? AppColors.danger : Colors.grey,
                                        title: 'Emergency Alerts',
                                        subtitle: subtitle,
                                        actionText: hasAlerts ? 'Review SOS' : 'History',
                                        isAlert: hasAlerts,
                                        onTap: () {
                                          final parentState = AdminDashboardScreen.of(context);
                                          if (parentState != null) {
                                            parentState.setIndex(8);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _OverviewCard(
                                    icon: Icons.speed_rounded,
                                    iconColor: AppColors.success,
                                    title: 'Speed Alerts Log',
                                    subtitle: '2 instances of speed exceeding 50km/h detected today.',
                                    actionText: 'Logs',
                                    onTap: () => _navigate(context, '/reports'),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            const _SectionTitle('Quick Actions'),
                            const SizedBox(height: 12),
                            
                            // Section 4: Quick Actions
                            AnimatedBuilder(
                              animation: _entryController,
                              builder: (context, child) => FadeTransition(
                                opacity: _fadeAnimations[4],
                                child: SlideTransition(
                                  position: _slideAnimations[4],
                                  child: child,
                                ),
                              ),
                              child: const _QuickActionsGrid(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  const _SectionTitle('System Overview'),
                  const SizedBox(height: 12),
                  
                  // Section 1: Main cards
                  AnimatedBuilder(
                    animation: _entryController,
                    builder: (context, child) => FadeTransition(
                      opacity: _fadeAnimations[1],
                      child: SlideTransition(
                        position: _slideAnimations[1],
                        child: child,
                      ),
                    ),
                    child: const _MainSectionCards(),
                  ),
                  
                  const SizedBox(height: 24),
                  const _SectionTitle('Quick Actions'),
                  const SizedBox(height: 12),
                  
                  // Section 2: Quick Actions
                  AnimatedBuilder(
                    animation: _entryController,
                    builder: (context, child) => FadeTransition(
                      opacity: _fadeAnimations[2],
                      child: SlideTransition(
                        position: _slideAnimations[2],
                        child: child,
                      ),
                    ),
                    child: const _QuickActionsGrid(),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSliverAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final isCollapsed = constraints.scrollOffset > 100;
        return SliverAppBar(
          expandedHeight: 190,
          collapsedHeight: 64,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: isDark
              ? const Color(0xFF311B92)
              : const Color(0xFF512DA8),
          title: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isCollapsed ? 1.0 : 0.0,
            child: const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF21005D), const Color(0xFF311B92)]
                          : [const Color(0xFF512DA8), AppColors.admin.primary],
                    ),
                  ),
                ),
                const Positioned.fill(child: _AdminHeaderAnimation()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome Admin 👋',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Text(
                                    'City Grammar School',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.today_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Monday, Oct 24',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'All Systems Normal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: const [SizedBox(width: 8)],
        );
      },
    );
  }
}

class _AdminHeaderAnimation extends StatefulWidget {
  const _AdminHeaderAnimation();

  @override
  State<_AdminHeaderAnimation> createState() => _AdminHeaderAnimationState();
}

class _AdminHeaderAnimationState extends State<_AdminHeaderAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _AdminHeaderPainter(
            progress: _controller.value,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _AdminHeaderPainter extends CustomPainter {
  const _AdminHeaderPainter({required this.progress, required this.isDark});
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.05 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.15 : 0.25)
      ..style = PaintingStyle.fill;

    final nodes = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.8),
    ];

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      nodes[i] = Offset(
        node.dx + math.sin(progress * 2 * math.pi + i) * 10,
        node.dy + math.cos(progress * 2 * math.pi + i) * 10,
      );
    }

    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        if ((nodes[i] - nodes[j]).distance < size.width * 0.5) {
          canvas.drawLine(nodes[i], nodes[j], paint);
        }
      }
    }

    for (var i = 0; i < nodes.length - 1; i++) {
      final p1 = nodes[i];
      final p2 = nodes[i + 1];
      final t = (progress + (i * 0.2)) % 1.0;
      final currentPos = Offset(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
      canvas.drawCircle(currentPos, 3, dotPaint);
    }

    for (var node in nodes) {
      canvas.drawCircle(node, 4, dotPaint);
      canvas.drawCircle(
        node,
        8 + math.sin(progress * 4 * math.pi) * 2,
        paint..color = Colors.white.withValues(alpha: 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdminHeaderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200 ? 4 : (width >= 700 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: width >= 1200 ? 1.8 : (width >= 700 ? 2.2 : 2.6),
          children: [
            // 1. Buses
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('buses').snapshots(),
              builder: (context, snapshot) {
                final total = snapshot.data?.docs.length ?? 0;
                final active = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == 'active';
                }).length ?? 0;
                return _StatCard(
                  title: 'Total Buses',
                  value: total,
                  subtitle: '$active Active',
                  icon: Icons.directions_bus_rounded,
                  color: AppColors.parent.primary,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),

            // 2. Drivers
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'driver')
                  .snapshots(),
              builder: (context, snapshot) {
                final total = snapshot.data?.docs.length ?? 0;
                final standby = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? '';
                  return status == 'standby' || status == 'inactive';
                }).length ?? 0;
                return _StatCard(
                  title: 'Total Drivers',
                  value: total,
                  subtitle: '$standby Standby',
                  icon: Icons.badge_rounded,
                  color: AppColors.success,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),

            // 3. Students
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, snapshot) {
                final total = snapshot.data?.docs.length ?? 0;
                final assigned = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final busId = data['assignedBusId'] as String?;
                  return busId != null && busId.isNotEmpty;
                }).length ?? 0;
                return _StatCard(
                  title: 'Students',
                  value: total,
                  subtitle: '$assigned Assigned',
                  icon: Icons.school_rounded,
                  color: AppColors.warning,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),

            // 4. Routes
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('routes').snapshots(),
              builder: (context, snapshot) {
                final total = snapshot.data?.docs.length ?? 0;
                final active = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == 'active';
                }).length ?? 0;
                return _StatCard(
                  title: 'Routes',
                  value: total,
                  subtitle: '$active Active',
                  icon: Icons.alt_route_rounded,
                  color: AppColors.admin.primary,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.loading = false,
  });

  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool loading;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh)
              : (isDark
                  ? scheme.surfaceContainerHigh
                  : scheme.surfaceContainerLow),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.5)
                : scheme.outlineVariant,
            width: _isHovered ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.15)
                  : widget.color.withValues(alpha: 0.05),
              blurRadius: _isHovered ? 16 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                Icon(
                  Icons.more_horiz_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.loading) ...[
              const _ShimmerPlaceholder(width: 60, height: 24),
              const SizedBox(height: 4),
              const _ShimmerPlaceholder(width: 80, height: 12),
              const SizedBox(height: 4),
              const _ShimmerPlaceholder(width: 100, height: 10),
            ] else ...[
              AnimatedCountText(
                value: widget.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: widget.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MainSectionCards extends StatelessWidget {
  const _MainSectionCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewCard(
          icon: Icons.map_rounded,
          iconColor: AppColors.parent.primary,
          title: 'Live Bus Map Preview',
          subtitle: 'Track 4 active buses on routes.',
          actionText: 'View Map',
          onTap: () => _navigate(context, '/admin-live-tracking'),
        ),
        const SizedBox(height: 12),
        _OverviewCard(
          icon: Icons.history_rounded,
          iconColor: const Color(0xFF7B2FBE),
          title: 'Recent Trips',
          subtitle: 'View completed trips and performance.',
          actionText: 'View All',
          onTap: () => _navigate(context, '/reports'),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('emergency_alerts')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            final activeDocs = snapshot.data?.docs ?? [];
            final count = activeDocs.length;
            final hasAlerts = count > 0;

            String subtitle = 'No active alerts at the moment.';
            if (count == 1) {
              final type = (activeDocs.first.data() as Map<String, dynamic>)['type'] ?? 'Emergency';
              final driver = (activeDocs.first.data() as Map<String, dynamic>)['driverName'] ?? 'Driver';
              subtitle = '1 active alert: $type reported by $driver.';
            } else if (count > 1) {
              subtitle = '$count active alerts require attention!';
            }

            return _OverviewCard(
              icon: Icons.warning_rounded,
              iconColor: hasAlerts ? AppColors.danger : Colors.grey,
              title: 'Emergency Alerts',
              subtitle: subtitle,
              actionText: hasAlerts ? 'Review SOS' : 'History',
              isAlert: hasAlerts,
              onTap: () {
                final parentState = AdminDashboardScreen.of(context);
                if (parentState != null) {
                  parentState.setIndex(8);
                }
              },
            );
          },
        ),
      ],
    );
  }

  void _navigate(BuildContext context, String routeName) {
    if (!AdminDashboardScreen.navigateToTab(context, routeName)) {
      Navigator.pushNamed(context, routeName);
    }
  }
}

class _OverviewCard extends StatefulWidget {
  const _OverviewCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onTap,
    this.isAlert = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onTap;
  final bool isAlert;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isAlert
                  ? (isDark
                      ? AppColors.danger.withValues(alpha: _isHovered ? 0.25 : 0.15)
                      : AppColors.danger.withValues(alpha: _isHovered ? 0.12 : 0.08))
                  : (_isHovered
                      ? (isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh)
                      : scheme.surfaceContainerLow),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isAlert
                    ? AppColors.danger.withValues(alpha: _isHovered ? 0.6 : 0.3)
                    : (_isHovered
                        ? widget.iconColor.withValues(alpha: 0.5)
                        : scheme.outlineVariant),
                width: widget.isAlert || _isHovered ? 1.5 : 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isAlert
                      ? AppColors.danger.withValues(alpha: _isHovered ? 0.15 : 0.05)
                      : (_isHovered
                          ? widget.iconColor.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: isDark ? 0.05 : 0.01)),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 8 : 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isAlert
                        ? AppColors.danger
                        : (_isHovered ? scheme.primary : scheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.actionText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.isAlert || _isHovered ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 3;
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
        // The item content needs around 100px of vertical space. 
        // By dividing the item width by 100, we get an aspect ratio that ensures the height is always 100.
        final aspectRatio = itemWidth / 100.0;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
        _ActionItem(
          icon: Icons.directions_bus_rounded,
          label: 'Buses',
          color: AppColors.parent.primary,
          onTap: () => _navigate(context, '/manage-buses'),
        ),
        _ActionItem(
          icon: Icons.badge_rounded,
          label: 'Drivers',
          color: AppColors.success,
          onTap: () => _navigate(context, '/manage-drivers'),
        ),
        _ActionItem(
          icon: Icons.school_rounded,
          label: 'Students',
          color: AppColors.warning,
          onTap: () => _navigate(context, '/manage-students'),
        ),
        _ActionItem(
          icon: Icons.family_restroom_rounded,
          label: 'Parents',
          color: const Color(0xFF00838F),
          onTap: () => _navigate(context, '/manage-parents'),
        ),
        _ActionItem(
          icon: Icons.alt_route_rounded,
          label: 'Routes',
          color: AppColors.admin.primary,
          onTap: () => _navigate(context, '/manage-routes'),
        ),
        _ActionItem(
          icon: Icons.assignment_ind_rounded,
          label: 'Assign',
          color: const Color(0xFF42A5F5),
          onTap: () => _navigate(context, '/assign-bus'),
        ),
      ],
        );
      },
    );
  }

  void _navigate(BuildContext context, String routeName) {
    if (!AdminDashboardScreen.navigateToTab(context, routeName)) {
      Navigator.pushNamed(context, routeName);
    }
  }
}

class _ActionItem extends StatefulWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? widget.color.withValues(alpha: 0.2)
                      : widget.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isHovered
                        ? widget.color.withValues(alpha: 0.6)
                        : widget.color.withValues(alpha: 0.2),
                    width: _isHovered ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_isHovered)
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _isHovered ? FontWeight.w800 : FontWeight.w700,
                  color: _isHovered ? widget.color : scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Animated count display for stats grids
// ───────────────────────────────────────────────────────────────
class AnimatedCountText extends StatefulWidget {
  const AnimatedCountText({
    super.key,
    required this.value,
    this.style,
  });

  final int value;
  final TextStyle? style;

  @override
  State<AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<AnimatedCountText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: oldWidget.value.toDouble(),
        end: widget.value.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.toInt().toString(),
          style: widget.style,
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Skeleton Shimmer Loading Placeholder
// ───────────────────────────────────────────────────────────────
class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder({required this.width, required this.height});
  final double width;
  final double height;

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Opacity(
          opacity: _pulse.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Live Dashboard Map Panel (Real online bus positions)
// ───────────────────────────────────────────────────────────────
class LiveDashboardMapPanel extends StatefulWidget {
  const LiveDashboardMapPanel({super.key});

  @override
  State<LiveDashboardMapPanel> createState() => _LiveDashboardMapPanelState();
}

class _LiveDashboardMapPanelState extends State<LiveDashboardMapPanel> {
  final MapController _mapController = MapController();
  String? _selectedBusId;
  bool _hasMovedToActive = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('buses').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            height: 330,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('Error loading live map preview')),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final activeBuses = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['currentLat'] != null && data['currentLng'] != null;
        }).toList();

        // If a bus is selected, but it went offline, clear selection
        if (_selectedBusId != null && !activeBuses.any((b) => b.id == _selectedBusId)) {
          _selectedBusId = null;
        }

        // Default selection to first active bus
        if (_selectedBusId == null && activeBuses.isNotEmpty) {
          _selectedBusId = activeBuses.first.id;
        }

        // Center coordinates: selected bus, or first active bus, or default Karachi
        LatLng center = const LatLng(24.8607, 67.0011);
        Map<String, dynamic>? selectedBusData;

        if (_selectedBusId != null) {
          final selDoc = activeBuses.firstWhere((b) => b.id == _selectedBusId);
          selectedBusData = selDoc.data() as Map<String, dynamic>;
          center = LatLng(
            (selectedBusData['currentLat'] as num).toDouble(),
            (selectedBusData['currentLng'] as num).toDouble(),
          );
        } else if (activeBuses.isNotEmpty) {
          final data = activeBuses.first.data() as Map<String, dynamic>;
          center = LatLng(
            (data['currentLat'] as num).toDouble(),
            (data['currentLng'] as num).toDouble(),
          );
        }

        // Move map once on first load
        if (activeBuses.isNotEmpty && !_hasMovedToActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(center, 13.5);
          });
          _hasMovedToActive = true;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 330,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: isDark
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.buslocationtracker.app',
                    ),
                    MarkerLayer(
                      markers: activeBuses.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final lat = (data['currentLat'] as num).toDouble();
                        final lng = (data['currentLng'] as num).toDouble();
                        final isSelected = doc.id == _selectedBusId;

                        return Marker(
                          point: LatLng(lat, lng),
                          width: isSelected ? 50 : 40,
                          height: isSelected ? 50 : 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedBusId = doc.id;
                              });
                              _mapController.move(LatLng(lat, lng), 14.5);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? scheme.primary : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: isSelected ? Colors.white : scheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.directions_bus_rounded,
                                color: isSelected ? Colors.white : scheme.primary,
                                size: isSelected ? 22 : 18,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                
                // Map Label Chip
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar_rounded, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Live Tracking Area',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected Bus Card or Offline Warning overlay
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: selectedBusData != null
                      ? Container(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                            ],
                            border: Border.all(color: scheme.outlineVariant, width: 0.8),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.directions_bus_rounded, color: scheme.primary),
                            ),
                            title: Text(
                              selectedBusData['busNumber'] ?? 'Unnamed Bus',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Speed: ${selectedBusData['currentSpeed']?.toStringAsFixed(1) ?? '0.0'} km/h · Plate: ${selectedBusData['plateNumber'] ?? 'N/A'}',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ONLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                            ],
                            border: Border.all(color: scheme.outlineVariant, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: scheme.error, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'All buses are offline',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'GPS tracking is currently inactive.',
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                                    ),
                                  ],
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
      },
    );
  }
}
