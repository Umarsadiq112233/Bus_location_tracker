import 'dart:math' as math;
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/modules/driver/emergency_screen.dart';
import 'package:bus_location_tracker/modules/driver/route_stops_screen.dart';
import 'package:bus_location_tracker/modules/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:bus_location_tracker/core/utils/profile_image_helper.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

// ═══════════════════════════════════════════════════════════════
// Driver Dashboard Screen – Professional animated UI
// ═══════════════════════════════════════════════════════════════

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _driver;
  BusModel? _bus;
  RouteModel? _route;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = AuthService();
      final user = auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'No user logged in.';
          _isLoading = false;
        });
        return;
      }

      final driver = await auth.getUserData(user.uid);
      if (driver == null) {
        setState(() {
          _errorMessage = 'Driver data not found.';
          _isLoading = false;
        });
        return;
      }

      BusModel? bus;
      RouteModel? route;

      if (driver.assignedBusId != null && driver.assignedBusId!.isNotEmpty) {
        bus = await auth.fetchAssignedBus(driver.assignedBusId!);
        if (bus != null &&
            bus.assignedRouteId != null &&
            bus.assignedRouteId!.isNotEmpty) {
          route = await auth.fetchAssignedRoute(bus.assignedRouteId!);
        }
      } else {
        // Fallback: Query buses where assignedDriverId == driver.uid
        final busesSnapshot = await FirebaseFirestore.instance
            .collection('buses')
            .where('assignedDriverId', isEqualTo: driver.uid)
            .get();
        if (busesSnapshot.docs.isNotEmpty) {
          final busDoc = busesSnapshot.docs.first;
          bus = BusModel.fromMap(busDoc.data(), busDoc.id);
          if (bus.assignedRouteId != null && bus.assignedRouteId!.isNotEmpty) {
            route = await auth.fetchAssignedRoute(bus.assignedRouteId!);
          }
        }
      }

      setState(() {
        _driver = driver;
        _bus = bus;
        _route = route;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading driver data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const DriverDashboardSkeleton();
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: scheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadDriverData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      _DriverHomeTab(
        driver: _driver!,
        bus: _bus,
        route: _route,
        onRefresh: _loadDriverData,
      ),
      RouteStopsScreen(route: _route),
      EmergencyScreen(driver: _driver!, bus: _bus),
      ProfileScreen(
        driver: _driver,
        bus: _bus,
        route: _route,
        onProfileUpdated: _loadDriverData,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
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
                  icon: Icons.alt_route_rounded,
                  label: 'Route',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.warning_rounded,
                  label: 'Emergency',
                  isSelected: _currentIndex == 2,
                  activeColor: AppColors.danger,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Bottom Nav Item
// ───────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = activeColor ?? scheme.primary;

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

// ───────────────────────────────────────────────────────────────
// Home Tab Content
// ───────────────────────────────────────────────────────────────
class _DriverHomeTab extends StatefulWidget {
  const _DriverHomeTab({
    required this.driver,
    this.bus,
    this.route,
    required this.onRefresh,
  });

  final UserModel driver;
  final BusModel? bus;
  final RouteModel? route;
  final VoidCallback onRefresh;

  @override
  State<_DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<_DriverHomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;
  static const _sectionCount = 4;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimations = List.generate(_sectionCount, (index) {
      final start = index * 0.12;
      final end = start + 0.35;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(start, math.min(end, 1.0), curve: Curves.easeOut),
        ),
      );
    });

    _slideAnimations = List.generate(_sectionCount, (index) {
      final start = index * 0.12;
      final end = start + 0.35;
      return Tween<Offset>(
        begin: const Offset(0.0, 0.08),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(
            start,
            math.min(end, 1.0),
            curve: Curves.easeOutCubic,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _DriverSliverAppBar(
            driver: widget.driver,
            bus: widget.bus,
            route: widget.route,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // Section 0: Bus Assigned Card
                AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) => FadeTransition(
                    opacity: _fadeAnimations[0],
                    child: SlideTransition(
                      position: _slideAnimations[0],
                      child: child,
                    ),
                  ),
                  child: _BusAssignedCard(bus: widget.bus, route: widget.route),
                ),

                const SizedBox(height: 16),

                // Section 1: Trip Actions Card
                AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) => FadeTransition(
                    opacity: _fadeAnimations[1],
                    child: SlideTransition(
                      position: _slideAnimations[1],
                      child: child,
                    ),
                  ),
                  child: _TripActionsCard(
                    driver: widget.driver,
                    bus: widget.bus,
                    route: widget.route,
                    onRefresh: widget.onRefresh,
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('System Status'),
                const SizedBox(height: 8),

                // Section 2: System Status Grid
                AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) => FadeTransition(
                    opacity: _fadeAnimations[2],
                    child: SlideTransition(
                      position: _slideAnimations[2],
                      child: child,
                    ),
                  ),
                  child: const _SystemStatusGrid(),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Quick Actions'),
                const SizedBox(height: 8),

                // Section 3: Quick Actions Grid
                AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) => FadeTransition(
                    opacity: _fadeAnimations[3],
                    child: SlideTransition(
                      position: _slideAnimations[3],
                      child: child,
                    ),
                  ),
                  child: const _QuickActionsGrid(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Sliver AppBar with gradient header
// ───────────────────────────────────────────────────────────────
class _DriverSliverAppBar extends StatefulWidget {
  const _DriverSliverAppBar({required this.driver, this.bus, this.route});

  final UserModel driver;
  final BusModel? bus;
  final RouteModel? route;

  @override
  State<_DriverSliverAppBar> createState() => _DriverSliverAppBarState();
}

class _DriverSliverAppBarState extends State<_DriverSliverAppBar> {
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _loadLocalImage();
  }

  @override
  void didUpdateWidget(covariant _DriverSliverAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver.uid != widget.driver.uid) {
      _loadLocalImage();
    }
  }

  Future<void> _loadLocalImage() async {
    final bytes = await ProfileImageHelper.getProfileImage(widget.driver.uid);
    if (mounted) {
      setState(() {
        _localImageBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final isCollapsed = constraints.scrollOffset > 100;
        return SliverAppBar(
          expandedHeight: 180,
          collapsedHeight: 64,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.primary,
          title: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isCollapsed ? 1.0 : 0.0,
            child: const Row(
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Driver Dashboard',
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
                // Base Gradient – Professional Blue / Dark Navy
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                          : [AppColors.primary, const Color(0xFF0D47A1)],
                    ),
                  ),
                ),
                // Custom Professional Animation
                const Positioned.fill(child: _DriverHeaderAnimation()),
                // Content
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
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                image: _localImageBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(_localImageBytes!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _localImageBytes == null
                                  ? const Icon(
                                      Icons.person_pin_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ready for duty,',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    widget.driver.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.wifi_tethering_rounded,
                                    color: AppColors.success,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                                Icons.directions_bus_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.bus != null
                                    ? 'Bus ${widget.bus!.busNumber}'
                                    : 'No Bus',
                                style: const TextStyle(
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
                                Icons.route_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.route != null
                                    ? widget.route!.name
                                    : 'No Route',
                                style: const TextStyle(
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

// ───────────────────────────────────────────────────────────────
// Professional Header Animation (radar / network theme)
// ───────────────────────────────────────────────────────────────
class _DriverHeaderAnimation extends StatefulWidget {
  const _DriverHeaderAnimation();

  @override
  State<_DriverHeaderAnimation> createState() => _DriverHeaderAnimationState();
}

class _DriverHeaderAnimationState extends State<_DriverHeaderAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
          painter: _DriverHeaderPainter(
            progress: _controller.value,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _DriverHeaderPainter extends CustomPainter {
  const _DriverHeaderPainter({required this.progress, required this.isDark});
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.8;
    final cy = size.height * 0.3;

    // Radar rings
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.05 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), i * 40.0, paint);
    }

    // Radar sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.8, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 160))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: 160),
      progress * 2 * math.pi,
      math.pi / 2,
      true,
      sweepPaint,
    );

    // Blinking dots (GPS points)
    final random = math.Random(10);
    final dotPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: 0.3 + 0.3 * math.sin(progress * 2 * math.pi),
      )
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 5; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      if (math.sin(progress * math.pi + i) > 0) {
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DriverHeaderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

// ───────────────────────────────────────────────────────────────
// Slide to Start Trip Slider Widget
// ───────────────────────────────────────────────────────────────
class SlideToStartTripSlider extends StatefulWidget {
  const SlideToStartTripSlider({
    super.key,
    required this.onSlideCompleted,
    this.enabled = true,
  });

  final VoidCallback onSlideCompleted;
  final bool enabled;

  @override
  State<SlideToStartTripSlider> createState() => _SlideToStartTripSliderState();
}

class _SlideToStartTripSliderState extends State<SlideToStartTripSlider>
    with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (!widget.enabled) return;
    final delta = details.primaryDelta ?? 0.0;
    setState(() {
      final trackWidth = maxWidth - 56.0;
      _dragValue = (_dragValue + delta / trackWidth).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    if (_dragValue >= 0.85) {
      widget.onSlideCompleted();
      _reset();
    } else {
      _reset();
    }
  }

  void _reset() {
    _resetAnimation = Tween<double>(begin: _dragValue, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.addListener(() {
      setState(() {
        _dragValue = _resetAnimation.value;
      });
    });
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const thumbSize = 48.0;
        const trackHeight = 56.0;
        final maxTravel = width - thumbSize - 8.0;

        return Container(
          height: trackHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.enabled
                ? color.withValues(alpha: 0.08)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.enabled
                  ? color.withValues(alpha: 0.2)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Background sliding bar fill
              Positioned(
                left: 4,
                top: 4,
                bottom: 4,
                child: Container(
                  width: (thumbSize + (_dragValue * maxTravel)).clamp(
                    thumbSize,
                    width - 8.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.2), color],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),

              // Centered Guide Text
              Center(
                child: Opacity(
                  opacity: (1.0 - _dragValue * 1.5).clamp(0.0, 1.0),
                  child: Text(
                    'Slide to Start Trip',
                    style: TextStyle(
                      color: widget.enabled ? color : scheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              // Draggable Thumb
              Positioned(
                left: 4.0 + (_dragValue * maxTravel),
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _handleDragUpdate(d, width),
                  onHorizontalDragEnd: _handleDragEnd,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: color,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Pulsing Trip Status Indicator
// ───────────────────────────────────────────────────────────────
class _TripStatusIndicator extends StatefulWidget {
  const _TripStatusIndicator({required this.isActive});
  final bool isActive;

  @override
  State<_TripStatusIndicator> createState() => _TripStatusIndicatorState();
}

class _TripStatusIndicatorState extends State<_TripStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _TripStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.isActive) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(
                alpha: 0.1 + (_pulseController.value * 0.15),
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withValues(
                  alpha: 0.3 + (_pulseController.value * 0.4),
                ),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.success,
              size: 28,
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.location_off_rounded,
        color: scheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Bus Assigned Card
// ───────────────────────────────────────────────────────────────
class _BusAssignedCard extends StatelessWidget {
  const _BusAssignedCard({this.bus, this.route});

  final BusModel? bus;
  final RouteModel? route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isTripActive =
        bus != null && bus!.currentLat != null && bus!.currentLng != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRIP STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTripActive ? 'Active / On Duty' : 'Not Started',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isTripActive
                              ? AppColors.success
                              : scheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _TripStatusIndicator(isActive: isTripActive),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.directions_bus_rounded,
                    label: 'Bus',
                    value: bus != null ? bus!.busNumber : 'None',
                    color: AppColors.primary,
                  ),
                ),
                Container(width: 1, height: 40, color: scheme.outlineVariant),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.route_rounded,
                    label: 'Route',
                    value: route != null ? route!.name : 'None',
                    color: AppColors.secondary,
                  ),
                ),
                Container(width: 1, height: 40, color: scheme.outlineVariant),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.pin_drop_rounded,
                    label: 'Stops',
                    value: route != null
                        ? '${route!.stops?.length ?? 0} Stops'
                        : '0 Stops',
                    color: AppColors.warning,
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

class _InfoItem extends StatelessWidget {
  const _InfoItem({
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

    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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

// ───────────────────────────────────────────────────────────────
// Trip Actions Card (Start / End)
// ───────────────────────────────────────────────────────────────
class _TripActionsCard extends StatelessWidget {
  const _TripActionsCard({
    required this.driver,
    this.bus,
    this.route,
    required this.onRefresh,
  });

  final UserModel driver;
  final BusModel? bus;
  final RouteModel? route;
  final VoidCallback onRefresh;

  void _showProfileRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('Profile Incomplete'),
          ],
        ),
        content: const Text(
          'A phone number and driver license number are required to start a trip.\n\nPlease complete your profile credentials first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.editProfile).then((
                updated,
              ) {
                if (updated == true) {
                  onRefresh();
                }
              });
            },
            child: const Text('Update Profile'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTripActive =
        bus != null && bus!.currentLat != null && bus!.currentLng != null;

    if (isTripActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionButton(
            icon: Icons.navigation_rounded,
            label: 'Resume Active Trip Screen',
            color: AppColors.primary,
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.startTrip,
                arguments: {'driver': driver, 'bus': bus, 'route': route},
              ).then((_) => onRefresh());
            },
            isFilled: true,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.stop_rounded,
            label: 'End Active Trip',
            color: AppColors.danger,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('End Trip'),
                  content: const Text(
                    'Are you sure you want to end the active trip?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      child: const Text('End Trip'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AuthService().endBusTrip(bus!.id);
                onRefresh();
              }
            },
            isFilled: false,
          ),
        ],
      );
    }

    return SlideToStartTripSlider(
      enabled: bus != null && route != null,
      onSlideCompleted: () {
        if (driver.phone.trim().isEmpty ||
            driver.licenseNumber == null ||
            driver.licenseNumber!.trim().isEmpty) {
          _showProfileRequiredDialog(context);
          return;
        }
        Navigator.pushNamed(
          context,
          AppRoutes.startTrip,
          arguments: {'driver': driver, 'bus': bus, 'route': route},
        ).then((_) => onRefresh());
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isFilled,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isFilled
              ? color
              : (isDark ? color.withValues(alpha: 0.1) : Colors.white),
          borderRadius: BorderRadius.circular(28),
          border: isFilled
              ? null
              : Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: isFilled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isFilled ? Colors.white : color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isFilled ? Colors.white : color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// System Status Grid
// ───────────────────────────────────────────────────────────────
class _SystemStatusGrid extends StatelessWidget {
  const _SystemStatusGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatusTile(
                icon: Icons.gps_fixed_rounded,
                label: 'GPS Signal',
                value: 'Strong',
                color: AppColors.success,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatusTile(
                icon: Icons.share_location_rounded,
                label: 'Location Sharing',
                value: 'Active',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatusTile(
                icon: Icons.speed_rounded,
                label: 'Current Speed',
                value: '0 km/h',
                color: AppColors.warning,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatusTile(
                icon: Icons.battery_charging_full_rounded,
                label: 'Battery',
                value: '84%',
                color: AppColors.info,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusTile extends StatefulWidget {
  const _StatusTile({
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
  State<_StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<_StatusTile> {
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
        transform: Matrix4.translationValues(0.0, _isHovered ? -2.0 : 0.0, 0.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark
                    ? scheme.surfaceContainerHighest
                    : scheme.surfaceContainerHigh)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.5)
                : scheme.outlineVariant,
            width: _isHovered ? 1.0 : 0.5,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, color: widget.color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
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
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Quick Actions Grid
// ───────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width > 760) {
      return Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.alt_route_rounded,
              label: 'Route Stops',
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, AppRoutes.routeStops),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.history_rounded,
              label: 'Trip History',
              color: AppColors.warning,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.driverTripHistory),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.warning_rounded,
              label: 'Emergency Alert',
              color: AppColors.danger,
              onTap: () => Navigator.pushNamed(context, AppRoutes.emergency),
              isAlert: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.person_rounded,
              label: 'Profile',
              color: AppColors.success,
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.alt_route_rounded,
                  label: 'Route Stops',
                  color: AppColors.primary,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.routeStops),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.history_rounded,
                  label: 'Trip History',
                  color: AppColors.warning,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.driverTripHistory),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.warning_rounded,
                  label: 'Emergency Alert',
                  color: AppColors.danger,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.emergency),
                  isAlert: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  color: AppColors.success,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isAlert = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isAlert;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0.0,
            _isHovered ? -4.0 : 0.0,
            0.0,
          ),
          decoration: BoxDecoration(
            color: widget.isAlert
                ? widget.color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (_isHovered
                      ? widget.color.withValues(alpha: isDark ? 0.22 : 0.12)
                      : widget.color.withValues(alpha: isDark ? 0.15 : 0.08)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isAlert
                  ? widget.color.withValues(alpha: isDark ? 0.5 : 0.4)
                  : (_isHovered
                        ? widget.color.withValues(alpha: 0.6)
                        : widget.color.withValues(alpha: isDark ? 0.3 : 0.2)),
              width: widget.isAlert || _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isAlert
                        ? widget.color
                        : widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isAlert ? Colors.white : widget.color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: widget.isAlert
                        ? (isDark ? const Color(0xFFFF8A80) : widget.color)
                        : (isDark
                              ? Colors.white
                              : widget.color.withValues(alpha: 1.0)),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Shared Section Title
// ───────────────────────────────────────────────────────────────
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
