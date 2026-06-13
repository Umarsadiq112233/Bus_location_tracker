import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/widgets/maps/current_location_map.dart';
import 'package:bus_location_tracker/modules/parent/live_tracking_screen.dart';
import 'package:bus_location_tracker/modules/parent/parent_children_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/modules/profile/profile_screen.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'dart:typed_data';
import 'package:bus_location_tracker/core/utils/profile_image_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';

// ═══════════════════════════════════════════════════════════════
// Parent Home Screen — Professional UI
// ═══════════════════════════════════════════════════════════════

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  UserModel? _parentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final parent = await auth.getUserData(currentUser.uid);
        if (mounted) {
          setState(() {
            _parentUser = parent;
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

  void _goToProfile() => setState(() => _currentIndex = 3);
  void _goToChildren() => setState(() => _currentIndex = 1);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ParentDashboardSkeleton();
    }

    final pages = [
      _ParentHomeTab(
        parent: _parentUser,
        onProfileTap: _goToProfile,
        onChildrenTabTap: _goToChildren,
        onRefreshParentData: _loadParentData,
      ),
      const ParentChildrenScreen(),
      const LiveTrackingScreen(),
      ProfileScreen(onProfileUpdated: _loadParentData),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _ParentBottomNav(
        currentIndex: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Bottom Navigation Bar
// ───────────────────────────────────────────────────────────────
class _ParentBottomNav extends StatelessWidget {
  const _ParentBottomNav({required this.currentIndex, required this.onChanged});

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
                icon: Icons.child_care_rounded,
                label: 'Children',
                selected: currentIndex == 1,
                onTap: () => onChanged(1),
              ),
              _NavItem(
                icon: Icons.location_on_rounded,
                label: 'Tracking',
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

// ═══════════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════════
class _ParentHomeTab extends StatefulWidget {
  const _ParentHomeTab({
    required this.onProfileTap,
    required this.onChildrenTabTap,
    this.parent,
    this.onRefreshParentData,
  });
  final VoidCallback onProfileTap;
  final VoidCallback onChildrenTabTap;
  final UserModel? parent;
  final Future<void> Function()? onRefreshParentData;

  @override
  State<_ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<_ParentHomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  static const _count = 6;

  List<UserModel> _children = [];
  bool _loading = true;
  int _selectedChildIndex = 0;

  StreamSubscription? _busSub;
  BusModel? _liveBus;
  RouteModel? _route;
  List<LatLng> _roadPolyline = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fades = List.generate(_count, (i) {
      final s = i * 0.11;
      return CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(s, (s + 0.45).clamp(0, 1), curve: Curves.easeOut),
      );
    });
    _slides = List.generate(_count, (i) {
      final s = i * 0.11;
      return Tween<Offset>(
        begin: const Offset(0, 0.16),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(
            s,
            (s + 0.45).clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
    _loadChildrenAndStartStreams();
  }

  Future<void> _loadChildrenAndStartStreams() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _liveBus = null;
        _route = null;
        _roadPolyline = [];
      });
    }
    _busSub?.cancel();

    try {
      if (widget.onRefreshParentData != null) {
        await widget.onRefreshParentData!();
      }
      final uids = widget.parent?.childrenUids;
      if (uids != null && uids.isNotEmpty) {
        _children = await AuthService().fetchChildren(uids);

        if (_children.isNotEmpty) {
          _selectedChildIndex = 0;
          await _startBusStream();
        }
      }
    } catch (e) {
      debugPrint('Error loading parent children: $e');
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
      _animCtrl.reset();
      _animCtrl.forward();
    }
  }

  Future<void> _startBusStream() async {
    _busSub?.cancel();
    if (_children.isEmpty || _selectedChildIndex >= _children.length) return;

    final child = _children[_selectedChildIndex];
    if (child.assignedBusId == null || child.assignedBusId!.isEmpty) {
      setState(() {
        _liveBus = null;
        _route = null;
        _roadPolyline = [];
      });
      return;
    }

    try {
      final bus = await AuthService().fetchAssignedBus(child.assignedBusId!);
      if (bus != null) {
        setState(() {
          _liveBus = bus;
        });

        if (bus.assignedRouteId != null && bus.assignedRouteId!.isNotEmpty) {
          final route = await AuthService().fetchAssignedRoute(
            bus.assignedRouteId!,
          );
          if (route != null) {
            setState(() {
              _route = route;
            });

            try {
              final straightPoints = route.getPolylinePoints();
              if (straightPoints.length >= 2) {
                final coords = straightPoints
                    .map((p) => '${p.longitude},${p.latitude}')
                    .join(';');
                final url = Uri.parse(
                  'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
                );
                final response = await http.get(
                  url,
                  headers: {'User-Agent': 'com.example.bus_location_tracker'},
                );
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  if (data['routes'] != null && data['routes'].isNotEmpty) {
                    final geometry = data['routes'][0]['geometry'];
                    final List<dynamic> coordinates = geometry['coordinates'];
                    final roadPoints = coordinates
                        .map<LatLng>(
                          (c) => LatLng(
                            (c[1] as num).toDouble(),
                            (c[0] as num).toDouble(),
                          ),
                        )
                        .toList();
                    setState(() {
                      _roadPolyline = roadPoints;
                    });
                  }
                }
              }
            } catch (_) {
              setState(() {
                _roadPolyline = route.getPolylinePoints();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching initial bus/route: $e');
    }

    _busSub = AuthService().streamBus(child.assignedBusId!).listen((bus) {
      if (bus != null && mounted) {
        setState(() {
          _liveBus = bus;
        });
      }
    });
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _a(int i, Widget child) => FadeTransition(
    opacity: _fades[i],
    child: SlideTransition(position: _slides[i], child: child),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      body: RefreshIndicator(
        onRefresh: _loadChildrenAndStartStreams,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _ParentSliverHeader(
              parent: widget.parent,
              onProfileTap: widget.onProfileTap,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading)
                    const Column(
                      children: [
                        SkeletonBox(width: double.infinity, height: 38, borderRadius: 20),
                        SizedBox(height: 14),
                        SkeletonBox(width: double.infinity, height: 240, borderRadius: 24),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: SkeletonBox(height: 70, borderRadius: 16)),
                            SizedBox(width: 12),
                            Expanded(child: SkeletonBox(height: 70, borderRadius: 16)),
                          ],
                        ),
                      ],
                    )
                  else if (_children.isEmpty)
                    _a(0, _EmptyStateCard(onLinkTap: widget.onChildrenTabTap))
                  else ...[
                    _a(
                      0,
                      _ChildrenSelector(
                        children: _children,
                        selectedIndex: _selectedChildIndex,
                        onSelected: (idx) {
                          setState(() {
                            _selectedChildIndex = idx;
                          });
                          _startBusStream();
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildEmergencyAlertBanner(),
                    _a(
                      1,
                      _LiveMapHeroCard(
                        child: _children[_selectedChildIndex],
                        bus: _liveBus,
                        routePoints: _roadPolyline,
                        stops: _route?.stops,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _a(2, _BusStatusRow(bus: _liveBus, route: _route)),
                    const SizedBox(height: 14),
                    _a(3, const _QuickActionsCard()),
                    const SizedBox(height: 14),
                    _a(4, _TodayJourneyCard(route: _route, bus: _liveBus)),
                    const SizedBox(height: 14),
                    _a(5, const _RecentNotificationsCard()),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyAlertBanner() {
    if (_liveBus == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('busId', isEqualTo: _liveBus!.id)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final alert = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final type = alert['type'] ?? 'Emergency';
        final message = alert['message'] ?? '';
        final driverPhone = alert['driverPhone'] ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD64B4B),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🚨 BUS EMERGENCY DETECTED: $type',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.isNotEmpty
                      ? '"$message"'
                      : 'The driver of your child\'s school bus has triggered an emergency distress alert. School administration is aware, coordinates-tracking the bus, and has contacted response services.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (driverPhone.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _makePhoneCall(driverPhone),
                        icon: const Icon(
                          Icons.call,
                          size: 14,
                          color: Color(0xFFD64B4B),
                        ),
                        label: const Text(
                          'Call Driver',
                          style: TextStyle(
                            color: Color(0xFFD64B4B),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _makePhoneCall('03001234567'),
                      icon: const Icon(
                        Icons.support_agent_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Helpline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {}
  }
}

// ───────────────────────────────────────────────────────────────
// Empty State Card
// ───────────────────────────────────────────────────────────────
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.onLinkTap});
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          const Icon(
            Icons.child_care_rounded,
            size: 54,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 14),
          const Text(
            'No Children Linked',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Link your children in the Children tab to view their real-time school bus tracking and alerts here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onLinkTap,
            icon: const Icon(Icons.link),
            label: const Text('Link a Child Now'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.parent.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Sliver Header — dynamic with profile avatar tap
// ───────────────────────────────────────────────────────────────

class _ParentSliverHeader extends StatefulWidget {
  const _ParentSliverHeader({required this.onProfileTap, this.parent});
  final VoidCallback onProfileTap;
  final UserModel? parent;

  @override
  State<_ParentSliverHeader> createState() => _ParentSliverHeaderState();
}

class _ParentSliverHeaderState extends State<_ParentSliverHeader> {
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _loadLocalImage();
  }

  @override
  void didUpdateWidget(covariant _ParentSliverHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadLocalImage();
  }

  Future<void> _loadLocalImage() async {
    if (widget.parent != null) {
      final bytes = await ProfileImageHelper.getProfileImage(
        widget.parent!.uid,
      );
      if (mounted) {
        setState(() {
          _localImageBytes = bytes;
        });
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final name = parent != null && parent.name.isNotEmpty
        ? parent.name
        : 'Parent';
    final initials = parent != null ? _getInitials(parent.name) : 'PR';
    final childrenCount = parent?.childrenUids?.length ?? 0;
    final childrenText =
        '$childrenCount Child${childrenCount == 1 ? '' : 'ren'}';

    return SliverAppBar(
      expandedHeight: 148,
      collapsedHeight: 64,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.parent.primary,
      title: Row(
        children: [
          const Icon(
            Icons.directions_bus_filled_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Parent Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onProfileTap,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Colors.white.withValues(alpha: .2),
              backgroundImage: _localImageBytes != null
                  ? MemoryImage(_localImageBytes!)
                  : null,
              child: _localImageBytes == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.parent.primary, const Color(0xFF42A5F5)],
                ),
              ),
            ),
            const Positioned.fill(child: _HeaderWaveDecor()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFBBDEFB),
                              backgroundImage: _localImageBytes != null
                                  ? MemoryImage(_localImageBytes!)
                                  : null,
                              child: _localImageBytes == null
                                  ? Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.parent.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back 👋',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                childrenText,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.notifications,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('notifications')
                                  .where('userId', isEqualTo: parent?.uid ?? '')
                                  .where('isRead', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final unreadCount =
                                    snapshot.data?.docs.length ?? 0;
                                if (unreadCount == 0) {
                                  return const SizedBox.shrink();
                                }
                                return Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.parent.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
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

class _HeaderWaveDecor extends StatelessWidget {
  const _HeaderWaveDecor();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WavePainter());
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .07);
    canvas.drawCircle(Offset(size.width + 30, -20), 100, paint);
    canvas.drawCircle(Offset(-20, size.height + 10), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.5, -30), 60, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ───────────────────────────────────────────────────────────────
// Children selector chip row
// ───────────────────────────────────────────────────────────────
class _ChildrenSelector extends StatelessWidget {
  const _ChildrenSelector({
    required this.children,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<UserModel> children;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Child',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(children.length, (i) {
              final child = children[i];
              final active = selectedIndex == i;
              final gradeText = child.grade ?? "Grade N/A";
              return Padding(
                padding: EdgeInsets.only(
                  right: i < children.length - 1 ? 10 : 0,
                ),
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB),
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              const BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: active
                              ? Colors.white.withValues(alpha: .25)
                              : AppColors.primaryLight,
                          child: Text(
                            child.name.isNotEmpty
                                ? child.name.substring(0, 1).toUpperCase()
                                : 'S',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: active ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              gradeText,
                              style: TextStyle(
                                fontSize: 10,
                                color: active
                                    ? Colors.white70
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Live Map Hero Card (embedded OSM)
// ───────────────────────────────────────────────────────────────
class _LiveMapHeroCard extends StatelessWidget {
  const _LiveMapHeroCard({
    required this.child,
    this.bus,
    this.routePoints,
    this.stops,
  });

  final UserModel child;
  final BusModel? bus;
  final List<LatLng>? routePoints;
  final List<dynamic>? stops;

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        bus != null && bus!.currentLat != null && bus!.currentLng != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CurrentLocationMap(
                    initialZoom: 14.5,
                    recenterButtonBottom: 8,
                    showAttribution: false,
                    busLocation: hasLocation
                        ? LatLng(bus!.currentLat!, bus!.currentLng!)
                        : null,
                    routePoints: routePoints,
                    stops: stops,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .55),
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 14,
                    child: _BusOnWayChip(status: bus?.status),
                  ),
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
                            Text(
                              "${child.name.split(' ')[0]}'s Bus",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _EtaText(bus: bus),
                          ],
                        ),
                        const Spacer(),
                        if (hasLocation) _LivePill(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed:
                      child.assignedBusId != null &&
                          child.assignedBusId!.isNotEmpty
                      ? () => Navigator.pushNamed(
                          context,
                          AppRoutes.liveTracking,
                          arguments: {'busId': child.assignedBusId},
                        )
                      : null,
                  icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                  label: const Text(
                    'Track Live Bus',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.parent.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusOnWayChip extends StatelessWidget {
  const _BusOnWayChip({this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bus_rounded,
            size: 14,
            color: active ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'ON THE WAY' : 'OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.success : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EtaText extends StatelessWidget {
  const _EtaText({this.bus});
  final BusModel? bus;

  @override
  Widget build(BuildContext context) {
    final active =
        bus != null && bus!.currentLat != null && bus!.status == 'active';
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: active ? 'Arriving soon' : 'Offline / Stopped',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 7),
          SizedBox(width: 5),
          Text(
            'Live',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Bus Status Row (3 metric cards)
// ───────────────────────────────────────────────────────────────
class _BusStatusRow extends StatelessWidget {
  const _BusStatusRow({this.bus, this.route});
  final BusModel? bus;
  final RouteModel? route;

  @override
  Widget build(BuildContext context) {
    final hasLocation = bus != null && bus!.currentLat != null;
    final totalStops = route?.stops?.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.directions_bus_rounded,
            label: 'Bus',
            value: bus?.busNumber.isNotEmpty == true ? bus!.busNumber : 'N/A',
            color: AppColors.parent.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.speed_rounded,
            label: 'Speed',
            value: hasLocation
                ? '${bus!.currentLat != null ? (bus!.toMap()['speed'] ?? 0) : 0} km/h'
                : '0 km/h',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.route_rounded,
            label: 'Route Stops',
            value: totalStops > 0 ? '$totalStops stops' : 'N/A',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Quick Actions Card
// ───────────────────────────────────────────────────────────────
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _ActionItem(
                icon: Icons.child_care_rounded,
                label: 'Children',
                color: AppColors.parent.primary,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.parentChildren),
              ),
              _ActionItem(
                icon: Icons.history_rounded,
                label: 'History',
                color: const Color(0xFF7B2FBE),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.tripHistory),
              ),
              _ActionItem(
                icon: Icons.notifications_rounded,
                label: 'Alerts',
                color: AppColors.secondary,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              _ActionItem(
                icon: Icons.help_rounded,
                label: 'Support',
                color: AppColors.info,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.helpSupport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .18)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Today's Journey Timeline Card
// ───────────────────────────────────────────────────────────────
class _TodayJourneyCard extends StatelessWidget {
  const _TodayJourneyCard({this.route, this.bus});
  final RouteModel? route;
  final BusModel? bus;

  @override
  Widget build(BuildContext context) {
    final stops = route?.stops ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.parent.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timeline_rounded,
                  size: 18,
                  color: AppColors.parent.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Today's Journey",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (bus != null && bus!.status == 'active')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (stops.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No route stops assigned for this bus.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...List.generate(stops.length, (i) {
              final stop = stops[i];
              final sequence = stop['sequence'] ?? i;
              final stopName = stop['name'] ?? 'Stop';
              final completed =
                  bus != null && bus!.status == 'active'; // mock status

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color:
                                  (completed
                                          ? AppColors.success
                                          : AppColors.textMuted)
                                      .withValues(alpha: .12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: completed
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              size: 14,
                            ),
                          ),
                          if (i < stops.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: completed
                                      ? AppColors.success.withValues(alpha: .3)
                                      : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                stopName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: completed
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: completed
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              'Stop $sequence',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Recent Notifications Card
// ───────────────────────────────────────────────────────────────
class _RecentNotificationsCard extends StatelessWidget {
  const _RecentNotificationsCard();

  Color _getStatusColor(String type) {
    switch (type) {
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

  IconData _getStatusIcon(String type) {
    switch (type) {
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final dt = timestamp.toDate();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationService().getNotificationsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 16, borderRadius: 4),
                SizedBox(height: 16),
                SkeletonBox(width: double.infinity, height: 40, borderRadius: 8),
                SizedBox(height: 12),
                SkeletonBox(width: double.infinity, height: 40, borderRadius: 8),
              ],
            ),
          );
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        );
        if (docs.isNotEmpty) {
          docs.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        }

        final displayDocs = docs.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  const Text(
                    'Recent Alerts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.notifications,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (displayDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textMuted,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No recent alerts',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayDocs.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 20,
                    color: Color(0xFFF3F4F6),
                  ),
                  itemBuilder: (context, i) {
                    final data = displayDocs[i].data();
                    final title = data['title'] as String? ?? 'Alert';
                    final body = data['body'] as String? ?? '';
                    final type = data['type'] as String? ?? 'info';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final isUnread = !(data['isRead'] as bool? ?? false);

                    final icon = _getStatusIcon(type);
                    final color = _getStatusColor(type);
                    final timeStr = _formatTimestamp(createdAt);

                    return GestureDetector(
                      onTap: () {
                        if (isUnread) {
                          NotificationService().markAsRead(displayDocs[i].id);
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isUnread
                                              ? FontWeight.w900
                                              : FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
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
      },
    );
  }
}
