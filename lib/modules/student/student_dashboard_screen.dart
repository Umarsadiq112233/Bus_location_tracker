import 'dart:async';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/core/widgets/maps/current_location_map.dart';
import 'package:bus_location_tracker/modules/profile/profile_screen.dart';
import 'package:bus_location_tracker/modules/student/student_live_tracking_screen.dart';
import 'package:bus_location_tracker/modules/student/student_trip_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:latlong2/latlong.dart';
import 'dart:typed_data';
import 'package:bus_location_tracker/core/utils/profile_image_helper.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  UserModel? _studentUser;
  BusModel? _assignedBus;
  RouteModel? _assignedRoute;
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _busSubscription;
  StreamSubscription<DocumentSnapshot>? _routeSubscription;

  @override
  void initState() {
    super.initState();
    _listenToLiveUpdates();
    _loadStudentData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _busSubscription?.cancel();
    _routeSubscription?.cancel();
    super.dispose();
  }

  void _listenToLiveUpdates() {
    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _userSubscription?.cancel();
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen(
            (userSnap) async {
              if (!userSnap.exists) {
                if (mounted) setState(() => _isLoading = false);
                return;
              }

              final student = UserModel.fromMap(
                userSnap.data() as Map<String, dynamic>,
                userSnap.id,
              );
              final newBusId = student.assignedBusId;
              final oldBusId = _studentUser?.assignedBusId;

              if (mounted) {
                setState(() {
                  _studentUser = student;
                });
              }

              if (newBusId != null && newBusId.isNotEmpty) {
                if (newBusId != oldBusId || _busSubscription == null) {
                  _setupBusSubscription(newBusId);
                }
              } else {
                _busSubscription?.cancel();
                _busSubscription = null;
                _routeSubscription?.cancel();
                _routeSubscription = null;
                if (mounted) {
                  setState(() {
                    _assignedBus = null;
                    _assignedRoute = null;
                    _isLoading = false;
                  });
                }
              }
            },
            onError: (err) {
              if (mounted) setState(() => _isLoading = false);
            },
          );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupBusSubscription(String busId) {
    _busSubscription?.cancel();
    _busSubscription = FirebaseFirestore.instance
        .collection('buses')
        .doc(busId)
        .snapshots()
        .listen(
          (busSnap) async {
            if (!busSnap.exists) {
              if (mounted) {
                setState(() {
                  _assignedBus = null;
                  _assignedRoute = null;
                  _isLoading = false;
                });
              }
              return;
            }

            final bus = BusModel.fromMap(
              busSnap.data() as Map<String, dynamic>,
              busSnap.id,
            );
            final newRouteId = bus.assignedRouteId;
            final oldRouteId = _assignedBus?.assignedRouteId;

            if (mounted) {
              setState(() {
                _assignedBus = bus;
              });
            }

            if (newRouteId != null && newRouteId.isNotEmpty) {
              if (newRouteId != oldRouteId || _routeSubscription == null) {
                _setupRouteSubscription(newRouteId);
              }
            } else {
              _routeSubscription?.cancel();
              _routeSubscription = null;
              if (mounted) {
                setState(() {
                  _assignedRoute = null;
                  _isLoading = false;
                });
              }
            }
          },
          onError: (err) {
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  void _setupRouteSubscription(String routeId) {
    _routeSubscription?.cancel();
    _routeSubscription = FirebaseFirestore.instance
        .collection('routes')
        .doc(routeId)
        .snapshots()
        .listen(
          (routeSnap) {
            if (mounted) {
              setState(() {
                if (routeSnap.exists) {
                  _assignedRoute = RouteModel.fromMap(
                    routeSnap.data() as Map<String, dynamic>,
                    routeSnap.id,
                  );
                } else {
                  _assignedRoute = null;
                }
                _isLoading = false;
              });
            }
          },
          onError: (err) {
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  Future<void> _loadStudentData() async {
    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final student = await auth.getUserData(currentUser.uid);
        BusModel? bus;
        RouteModel? route;

        if (student != null &&
            student.assignedBusId != null &&
            student.assignedBusId!.isNotEmpty) {
          bus = await auth.fetchAssignedBus(student.assignedBusId!);
          if (bus != null &&
              bus.assignedRouteId != null &&
              bus.assignedRouteId!.isNotEmpty) {
            route = await auth.fetchAssignedRoute(bus.assignedRouteId!);
          }
        }

        if (mounted) {
          setState(() {
            _studentUser = student;
            _assignedBus = bus;
            _assignedRoute = route;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    _listenToLiveUpdates();
    await _loadStudentData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const StudentDashboardSkeleton();
    }

    final pages = [
      _StudentHomeTab(
        student: _studentUser,
        bus: _assignedBus,
        route: _assignedRoute,
        onRefresh: _refreshData,
      ),
      StudentLiveTrackingScreen(
        showBackButton: false,
        busId: _studentUser?.assignedBusId,
      ),
      StudentTripHistoryScreen(student: _studentUser),
      ProfileScreen(
        compactStudentMode: true,
        driver: _studentUser,
        bus: _assignedBus,
        route: _assignedRoute,
        onProfileUpdated: _refreshData,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _StudentBottomNav(
        currentIndex: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _StudentBottomNav extends StatelessWidget {
  const _StudentBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                icon: Icons.location_on_rounded,
                label: 'Tracking',
                selected: currentIndex == 1,
                onTap: () => onChanged(1),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onChanged(2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 3,
                onTap: () => onChanged(3),
              ),
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
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 50 : 36,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 21,
                color: selected ? blue : const Color(0xFF8A96A0),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? blue : const Color(0xFF8A96A0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentHomeTab extends StatefulWidget {
  const _StudentHomeTab({
    this.student,
    this.bus,
    this.route,
    required this.onRefresh,
  });
  final UserModel? student;
  final BusModel? bus;
  final RouteModel? route;
  final RefreshCallback onRefresh;

  @override
  State<_StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<_StudentHomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const _cardCount = 6;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnims = List.generate(_cardCount, (i) {
      final start = i * 0.12;
      return CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(
          start,
          (start + 0.4).clamp(0, 1),
          curve: Curves.easeOut,
        ),
      );
    });

    _slideAnims = List.generate(_cardCount, (i) {
      final start = i * 0.12;
      return Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(
            start,
            (start + 0.4).clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(position: _slideAnims[index], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _animated(
                  0,
                  _HomeHeader(student: widget.student, bus: widget.bus),
                ),
                const SizedBox(height: 14),
                _animated(
                  1,
                  _ArrivalHeroCard(bus: widget.bus, route: widget.route),
                ),
                const SizedBox(height: 12),
                _animated(
                  2,
                  _InfoCardsRow(bus: widget.bus, route: widget.route),
                ),
                const SizedBox(height: 12),
                _animated(3, const _StudentQuickActions()),
                const SizedBox(height: 12),
                _animated(4, const _ScheduleCard()),
                const SizedBox(height: 12),
                _animated(
                  5,
                  _TimelineCard(route: widget.route, bus: widget.bus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatefulWidget {
  const _HomeHeader({this.student, this.bus});
  final UserModel? student;
  final BusModel? bus;

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader> {
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _loadLocalImage();
  }

  @override
  void didUpdateWidget(covariant _HomeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student?.uid != widget.student?.uid) {
      _loadLocalImage();
    }
  }

  Future<void> _loadLocalImage() async {
    if (widget.student != null) {
      final bytes = await ProfileImageHelper.getProfileImage(
        widget.student!.uid,
      );
      if (mounted) {
        setState(() {
          _localImageBytes = bytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.student != null && widget.student!.name.isNotEmpty
        ? widget.student!.name
        : 'Student';
    final active = widget.bus != null && widget.bus!.status == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              image: _localImageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_localImageBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _localImageBytes == null
                ? Center(
                    child: Text(
                      name.trim().isNotEmpty
                          ? name
                                .trim()
                                .split(RegExp(r'\s+'))
                                .map((e) => e[0])
                                .take(2)
                                .join()
                                .toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name 👋',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.success
                            : const Color(0xFF9CA3AF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      active
                          ? 'Bus is active on route'
                          : 'Bus is currently offline',
                      style: TextStyle(
                        color: active ? AppColors.success : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFF1F3), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.student != null
                  ? NotificationService().getNotificationsStream(
                      widget.student!.uid,
                    )
                  : const Stream.empty(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  unreadCount = snapshot.data!.docs
                      .where((doc) => !(doc.data()['isRead'] as bool? ?? false))
                      .length;
                }

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.studentNotifications,
                      ),
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.danger.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalHeroCard extends StatelessWidget {
  const _ArrivalHeroCard({this.bus, this.route});
  final BusModel? bus;
  final RouteModel? route;

  RouteModel _createFallbackRoute(RouteModel? original) {
    return RouteModel(
      id: original?.id ?? 'fallback_route',
      name: original?.name.isNotEmpty == true
          ? original!.name
          : 'Gulberg Greens To G-11 Route',
      startPoint: 'Gulberg Greens',
      endPoint: 'G-11 Islamabad',
      startLat: 33.5950,
      startLng: 73.1250,
      endLat: 33.6800,
      endLng: 72.9900,
      stops: [
        {
          'name': 'Gulberg Greens Start',
          'lat': 33.5950,
          'lng': 73.1250,
          'sequence': 1,
        },
        {
          'name': 'Sohan Junction',
          'lat': 33.6350,
          'lng': 73.1050,
          'sequence': 2,
        },
        {
          'name': 'Zero Point Interchange',
          'lat': 33.6900,
          'lng': 73.0500,
          'sequence': 3,
        },
        {
          'name': 'G-11 Terminal',
          'lat': 33.6800,
          'lng': 72.9900,
          'sequence': 4,
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = bus != null && bus!.status == 'active';

    RouteModel displayRoute = route ?? _createFallbackRoute(route);
    if (displayRoute.startLat == null || displayRoute.startLng == null) {
      displayRoute = _createFallbackRoute(displayRoute);
    }

    final hasBusLocation =
        bus != null &&
        bus!.currentLat != null &&
        bus!.currentLng != null &&
        bus!.currentLat != 0.0;
    final busLatLng = hasBusLocation
        ? LatLng(bus!.currentLat!, bus!.currentLng!)
        : const LatLng(33.5950, 73.1250);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CurrentLocationMap(
                    initialZoom: 15.5,
                    recenterButtonBottom: 8,
                    showAttribution: false,
                    busLocation: busLatLng,
                    routePoints: displayRoute.getPolylinePoints(),
                    stops: displayRoute.stops,
                    showControls: false,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.success
                                  : const Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            active ? 'ON THE WAY' : 'OFFLINE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: active
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(top: 12, right: 14, child: _OsmBadge()),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Live Status',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              active ? 'Arriving soon' : 'Offline / Stopped',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (hasBusLocation)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Live',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
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
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _MiniStatus(
                        icon: Icons.location_on_rounded,
                        title: 'Start Point',
                        value: displayRoute.startPoint.isNotEmpty == true
                            ? displayRoute.startPoint
                            : 'N/A',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      _MiniStatus(
                        icon: Icons.check_rounded,
                        title: 'Safety status',
                        value: active ? 'Active' : 'Offline',
                        color: active ? AppColors.success : AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: bus != null
                          ? () => Navigator.pushNamed(
                              context,
                              AppRoutes.studentLiveTracking,
                              arguments: {'busId': bus!.id},
                            )
                          : null,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text(
                        'Track Live Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

class _OsmBadge extends StatelessWidget {
  const _OsmBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 12, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'OpenStreetMap',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
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

class _InfoCardsRow extends StatelessWidget {
  const _InfoCardsRow({this.bus, this.route});
  final BusModel? bus;
  final RouteModel? route;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SimpleInfoCard(
            icon: Icons.directions_bus_rounded,
            title: 'Route information',
            lines: [
              'Bus number',
              bus?.busNumber.isNotEmpty == true
                  ? bus!.busNumber
                  : 'Not Assigned',
              'Route name',
              route?.name.isNotEmpty == true ? route!.name : 'Not Assigned',
            ],
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SimpleInfoCard(
            icon: Icons.calendar_month_outlined,
            title: 'Schedule',
            lines: ['Morning Pickup', '07:15 am', 'Evening Drop', '03:45 pm'],
            color: const Color(0xFF4A8B27),
          ),
        ),
      ],
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  const _SimpleInfoCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.color,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < lines.length; i += 2) ...[
            Text(
              lines[i].toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              lines[i + 1],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (i < lines.length - 2) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StudentQuickActions extends StatelessWidget {
  const _StudentQuickActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ActionPill(
                icon: Icons.alt_route_rounded,
                label: 'Route Stops',
                color: AppColors.primary,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.studentRouteStops),
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.studentNotifications,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionPill(
                icon: Icons.history_rounded,
                label: 'Trip History',
                color: const Color(0xFF10B981),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.studentTripHistory),
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Icons.person_rounded,
                label: 'Profile',
                color: const Color(0xFF8B5CF6),
                onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
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
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .12), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF3B82F6),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timetable Schedule',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pickup and drop times',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ScheduleRow(
            icon: Icons.wb_sunny_rounded,
            label: 'Morning Pickup',
            time: '07:15 AM',
            bg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _ScheduleRow(
            icon: Icons.nights_stay_rounded,
            label: 'Evening Drop',
            time: '03:45 PM',
            bg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.bg,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String time;
  final Color bg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({this.route, this.bus});
  final RouteModel? route;
  final BusModel? bus;

  RouteModel _createFallbackRoute(RouteModel? original) {
    return RouteModel(
      id: original?.id ?? 'fallback_route',
      name: original?.name.isNotEmpty == true
          ? original!.name
          : 'Gulberg Greens To G-11 Route',
      startPoint: 'Gulberg Greens',
      endPoint: 'G-11 Islamabad',
      startLat: 33.5950,
      startLng: 73.1250,
      endLat: 33.6800,
      endLng: 72.9900,
      stops: [
        {
          'name': 'Gulberg Greens Start',
          'lat': 33.5950,
          'lng': 73.1250,
          'sequence': 1,
        },
        {
          'name': 'Sohan Junction',
          'lat': 33.6350,
          'lng': 73.1050,
          'sequence': 2,
        },
        {
          'name': 'Zero Point Interchange',
          'lat': 33.6900,
          'lng': 73.0500,
          'sequence': 3,
        },
        {
          'name': 'G-11 Terminal',
          'lat': 33.6800,
          'lng': 72.9900,
          'sequence': 4,
        },
      ],
    );
  }

  int _getNearestStopIndex(List<dynamic> stops, BusModel? bus) {
    if (bus == null ||
        bus.currentLat == null ||
        bus.currentLng == null ||
        stops.isEmpty) {
      return 0;
    }
    double minDistance = double.maxFinite;
    int nearestIndex = 0;
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final double? lat = stop['lat'] != null
          ? (stop['lat'] as num).toDouble()
          : null;
      final double? lng = stop['lng'] != null
          ? (stop['lng'] as num).toDouble()
          : null;
      if (lat != null && lng != null) {
        final double dy = lat - bus.currentLat!;
        final double dx = lng - bus.currentLng!;
        final double distSq = dy * dy + dx * dx;
        if (distSq < minDistance) {
          minDistance = distSq;
          nearestIndex = i;
        }
      }
    }
    return nearestIndex;
  }

  @override
  Widget build(BuildContext context) {
    RouteModel displayRoute = route ?? _createFallbackRoute(route);
    if (displayRoute.stops == null || displayRoute.stops!.isEmpty) {
      displayRoute = _createFallbackRoute(displayRoute);
    }
    final stops = displayRoute.stops ?? [];
    final active = bus != null && bus!.status == 'active';
    final nearestStopIndex = active ? _getNearestStopIndex(stops, bus) : -1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Sequence Stops',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bus progression track order',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (stops.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No route timeline details available.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                final sequence = stop['sequence'] ?? (index + 1);
                final name = stop['name'] ?? 'Stop';
                final isLast = index == stops.length - 1;

                // Stop state logic based on nearest index
                final bool isCompleted = active && index < nearestStopIndex;
                final bool isActiveStop = active && index == nearestStopIndex;
                final bool isUpcoming = !active || index > nearestStopIndex;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!isLast)
                              Positioned(
                                top: 24,
                                bottom: 0,
                                child: Container(
                                  width: 2.5,
                                  color: isCompleted
                                      ? AppColors.success.withValues(alpha: 0.8)
                                      : isActiveStop
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : const Color(0xFFEFF1F3),
                                ),
                              ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? AppColors.success
                                      : isActiveStop
                                      ? AppColors.primary
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCompleted
                                        ? AppColors.success
                                        : isActiveStop
                                        ? AppColors.primary
                                        : const Color(0xFFD1D5DB),
                                    width: isActiveStop ? 2.5 : 2,
                                  ),
                                  boxShadow: isCompleted
                                      ? [
                                          BoxShadow(
                                            color: AppColors.success.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : isActiveStop
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 11,
                                        )
                                      : isActiveStop
                                      ? const Icon(
                                          Icons.directions_bus_rounded,
                                          color: Colors.white,
                                          size: 11,
                                        )
                                      : Text(
                                          '$sequence',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isUpcoming
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isActiveStop
                                        ? Icons.my_location_rounded
                                        : isCompleted
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.schedule_rounded,
                                    size: 12,
                                    color: isCompleted
                                        ? AppColors.success
                                        : isActiveStop
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActiveStop
                                        ? 'Bus is nearby / Arriving'
                                        : isCompleted
                                        ? 'Passed'
                                        : 'Scheduled / Upcoming',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isCompleted
                                          ? AppColors.success
                                          : isActiveStop
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
