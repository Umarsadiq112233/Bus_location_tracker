import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/utils/snackbar_utils.dart';
import 'package:bus_location_tracker/core/widgets/maps/current_location_map.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentLiveTrackingScreen extends StatefulWidget {
  const StudentLiveTrackingScreen({
    super.key,
    this.showBackButton = true,
    this.busId,
  });

  final bool showBackButton;
  final String? busId;

  @override
  State<StudentLiveTrackingScreen> createState() =>
      _StudentLiveTrackingScreenState();
}

class _StudentLiveTrackingScreenState extends State<StudentLiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final MapController _mapController;
  CurrentLocationSnapshot? _location;

  String? _resolvedBusId;
  StreamSubscription? _busSub;
  BusModel? _liveBus;
  RouteModel? _route;
  List<LatLng> _roadPolyline = [];
  UserModel? _driverUser;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _resolvedBusId = widget.busId;
    _startTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedBusId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _resolvedBusId = args['busId'] as String?;
        if (_resolvedBusId != null) {
          _startTracking();
        }
      }
    }
  }

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

  BusModel _createFallbackBus(String id) {
    return BusModel(
      id: id,
      busNumber: 'Islamabad-3434',
      plateNumber: 'ICT-3434',
      capacity: 40,
      status: 'active',
      currentLat: 33.5950,
      currentLng: 73.1250,
    );
  }

  Future<void> _loadOSRMRoute(RouteModel route) async {
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
            if (mounted) {
              setState(() {
                _roadPolyline = roadPoints;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading OSRM route: $e');
    }

    if (mounted) {
      setState(() {
        _roadPolyline = route.getPolylinePoints();
      });
    }
  }

  void _fitCameraToRoute() {
    final List<LatLng> points = [];
    if (_liveBus != null &&
        _liveBus!.currentLat != null &&
        _liveBus!.currentLng != null &&
        _liveBus!.currentLat != 0.0) {
      points.add(LatLng(_liveBus!.currentLat!, _liveBus!.currentLng!));
    } else {
      points.add(const LatLng(33.5950, 73.1250));
    }
    if (_roadPolyline.isNotEmpty) {
      points.addAll(_roadPolyline);
    }
    if (_route?.stops != null) {
      for (var stop in _route!.stops!) {
        if (stop is Map && stop['lat'] != null && stop['lng'] != null) {
          points.add(
            LatLng(
              (stop['lat'] as num).toDouble(),
              (stop['lng'] as num).toDouble(),
            ),
          );
        }
      }
    }
    if (points.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.only(
            left: 50.0,
            right: 50.0,
            top: 50.0,
            bottom: 220.0,
          ),
        ),
      );
    }
  }

  Future<void> _startTracking() async {
    _busSub?.cancel();

    if (_resolvedBusId == null || _resolvedBusId!.isEmpty) {
      try {
        final auth = AuthService();
        final currentUser = auth.currentUser;
        if (currentUser != null) {
          final user = await auth.getUserData(currentUser.uid);
          if (user != null) {
            if (user.role == UserRole.parent &&
                user.childrenUids != null &&
                user.childrenUids!.isNotEmpty) {
              final children = await auth.fetchChildren(user.childrenUids!);
              if (children.isNotEmpty) {
                _resolvedBusId = children.first.assignedBusId;
              }
            } else if (user.role == UserRole.student) {
              _resolvedBusId = user.assignedBusId;
            }
          }
        }
      } catch (e) {
        debugPrint('Error auto-resolving bus ID in tracking: $e');
      }
    }

    if (_resolvedBusId == null || _resolvedBusId!.isEmpty) {
      _resolvedBusId = 'fallback_bus';
    }

    try {
      final bus =
          await AuthService().fetchAssignedBus(_resolvedBusId!) ??
          _createFallbackBus(_resolvedBusId!);

      setState(() {
        _liveBus = bus;
      });

      if (bus.assignedDriverId != null && bus.assignedDriverId!.isNotEmpty) {
        final driver = await AuthService().getUserData(bus.assignedDriverId!);
        if (driver != null) {
          setState(() {
            _driverUser = driver;
          });
        }
      }

      RouteModel? route;
      if (bus.assignedRouteId != null && bus.assignedRouteId!.isNotEmpty) {
        route = await AuthService().fetchAssignedRoute(bus.assignedRouteId!);
      }
      if (route == null || route.startLat == null || route.startLng == null) {
        route = _createFallbackRoute(route);
      }

      setState(() {
        _route = route;
      });

      await _loadOSRMRoute(route);
    } catch (e) {
      debugPrint('Error starting live tracking: $e');
    }

    _busSub = AuthService().streamBus(_resolvedBusId!).listen((bus) {
      if (mounted) {
        if (bus != null) {
          setState(() {
            _liveBus = bus;
          });
        } else if (_liveBus == null) {
          setState(() {
            _liveBus = _createFallbackBus(_resolvedBusId!);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _controller.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBusLocation =
        _liveBus != null &&
        _liveBus!.currentLat != null &&
        _liveBus!.currentLng != null &&
        _liveBus!.currentLat != 0.0;
    final busLatLng = hasBusLocation
        ? LatLng(_liveBus!.currentLat!, _liveBus!.currentLng!)
        : const LatLng(33.5950, 73.1250);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: Stack(
        children: [
          Positioned.fill(
            child: CurrentLocationMap(
              initialZoom: 15.5,
              recenterButtonBottom: 138,
              showAttribution: false,
              busLocation: busLatLng,
              routePoints: _roadPolyline,
              stops: _route?.stops,
              mapController: _mapController,
              onLocationChanged: (location) {
                if (!mounted) return;
                setState(() => _location = location);
              },
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TopBar(
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.maybePop(context),
                  driver: _driverUser,
                  onRefresh: () {
                    _startTracking().then((_) {
                      _fitCameraToRoute();
                    });
                  },
                ),
                _buildEmergencyBanner(context),
              ],
            ),
          ),
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.14,
              minChildSize: 0.14,
              maxChildSize: 0.65,
              snap: true,
              snapSizes: const [0.14, 0.32, 0.65],
              builder: (context, scrollController) {
                return _BusDetailPanel(
                  bus: _liveBus,
                  route: _route,
                  location: _location,
                  scrollController: scrollController,
                  onStopTap: (lat, lng) {
                    _mapController.move(LatLng(lat, lng), 17.0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner(BuildContext context) {
    if (_resolvedBusId == null || _resolvedBusId!.isEmpty)
      return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('busId', isEqualTo: _resolvedBusId)
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

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade900,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _PulsingIcon(
                    icon: Icons.gpp_maybe_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🚨 ACTIVE EMERGENCY: $type',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message.isNotEmpty
                    ? '"$message"'
                    : 'The driver has reported an emergency. School administration has been notified and is responding.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (driverPhone.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _makePhoneCall(driverPhone),
                      icon: const Icon(
                        Icons.call,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Call Driver',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _makePhoneCall('03001234567'),
                    icon: const Icon(
                      Icons.support_agent_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Helpline',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (0.7 * _controller.value),
          child: Icon(widget.icon, color: widget.color, size: 22),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBackButton,
    required this.onBack,
    this.driver,
    this.onRefresh,
  });

  final bool showBackButton;
  final VoidCallback onBack;
  final UserModel? driver;
  final VoidCallback? onRefresh;

  void _handleMoreAction(BuildContext context, String value) {
    switch (value) {
      case 'refresh':
        onRefresh?.call();
        SnackbarUtils.showCustomSnackbar(
          context,
          'Map updated and re-centered.',
          isError: false,
        );
        break;
      case 'share':
        SnackbarUtils.showCustomSnackbar(
          context,
          'Tracking link copied to clipboard!',
          isError: false,
        );
        break;
      case 'call':
        if (driver != null && driver!.phone.isNotEmpty) {
          SnackbarUtils.showCustomSnackbar(
            context,
            'Calling Driver ${driver!.name} (${driver!.phone})...',
            isError: false,
          );
        } else {
          SnackbarUtils.showCustomSnackbar(
            context,
            'Driver contact info not available.',
            isError: true,
          );
        }
        break;
      case 'report':
        SnackbarUtils.showCustomSnackbar(
          context,
          'Delay reported successfully to Admin.',
          isError: false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _CircleButton(
            icon: showBackButton
                ? Icons.arrow_back_ios_new_rounded
                : Icons.menu_rounded,
            onTap: showBackButton ? onBack : () {},
          ),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bus Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'OpenStreetMap live tracking',
                  style: TextStyle(
                    color: Color(0xFF52606D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMoreAction(context, value),
            offset: const Offset(0, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text('Refresh Map'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text('Share Tracking'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'call',
                child: Row(
                  children: [
                    Icon(Icons.phone_rounded, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text('Call Driver'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report_problem_rounded, color: AppColors.danger),
                    SizedBox(width: 12),
                    Text(
                      'Report Delay',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
            child: const _CircleButton(
              icon: Icons.more_horiz_rounded,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .16),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: AppColors.textPrimary, size: 26),
        ),
      ),
    );
  }
}

class _BusDetailPanel extends StatelessWidget {
  const _BusDetailPanel({
    required this.bus,
    required this.route,
    required this.location,
    required this.scrollController,
    this.onStopTap,
  });

  final BusModel? bus;
  final RouteModel? route;
  final CurrentLocationSnapshot? location;
  final ScrollController scrollController;
  final Function(double lat, double lng)? onStopTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final hasLocation = bus != null && bus!.currentLat != null;
    final speed = hasLocation ? (bus!.toMap()['speed'] ?? 0) : 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 22,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            const _PanelHandle(),
            const SizedBox(height: 14),
            _BusSummaryCard(bus: bus, route: route),
            const SizedBox(height: 12),
            _LiveLocationCard(location: location, bus: bus),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.gps_fixed_rounded,
                    title: 'GPS status',
                    value: bus?.currentLat != null ? 'Active' : 'Searching',
                    note: bus?.currentLat != null ? 'Connected' : 'Offline',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.speed_rounded,
                    title: 'Current Speed',
                    value: '$speed km/h',
                    note: 'Live velocity',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _NotifyButton(),
            const SizedBox(height: 18),
            _RouteCard(
              route: route,
              active: bus?.status == 'active',
              onStopTap: onStopTap,
            ),
          ],
        ),
      ),
    );
  }
}

String _placeTitle(CurrentLocationSnapshot? location, BusModel? bus) {
  if (bus != null && bus.currentLat != null && bus.currentLng != null) {
    return 'Bus Position';
  }
  final address = location?.address;
  if (address != null) return address.shortName;
  if (location != null) return 'Resolving place';
  return 'Your location';
}

String _placeDetails(CurrentLocationSnapshot? location, BusModel? bus) {
  if (bus != null && bus.currentLat != null && bus.currentLng != null) {
    return 'Coordinates: ${bus.currentLat!.toStringAsFixed(4)}, ${bus.currentLng!.toStringAsFixed(4)}';
  }
  final address = location?.address;
  if (address != null) return address.displayName;
  if (location != null) {
    return '${location.point.latitude.toStringAsFixed(5)}, ${location.point.longitude.toStringAsFixed(5)}';
  }
  return 'Allow location permission to show your real current place.';
}

class _PanelHandle extends StatelessWidget {
  const _PanelHandle();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD2D8DF),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _BusSummaryCard extends StatelessWidget {
  const _BusSummaryCard({this.bus, this.route});
  final BusModel? bus;
  final RouteModel? route;

  @override
  Widget build(BuildContext context) {
    final active = bus != null && bus!.status == 'active';
    final busNum = bus?.busNumber.isNotEmpty == true
        ? bus!.busNumber
        : 'Bus N/A';
    final routeName = route?.name.isNotEmpty == true
        ? route!.name
        : 'No route assigned';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.directions_bus_filled_rounded,
              color: Color(0xFFEF9D00),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bus $busNum',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  routeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: active ? 'Active' : 'Offline',
            color: active ? AppColors.success : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _LiveLocationCard extends StatelessWidget {
  const _LiveLocationCard({required this.location, this.bus});

  final CurrentLocationSnapshot? location;
  final BusModel? bus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _PulsingLocationIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current location'.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _placeTitle(location, bus),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _placeDetails(location, bus),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
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

class _PulsingLocationIcon extends StatefulWidget {
  const _PulsingLocationIcon();

  @override
  State<_PulsingLocationIcon> createState() => _PulsingLocationIconState();
}

class _PulsingLocationIconState extends State<_PulsingLocationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * .08);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFFE5F0FF),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: Color(0xFF0A6FE8),
          size: 32,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NotifyButton extends StatelessWidget {
  const _NotifyButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.notifications_active_outlined, size: 26),
      label: const Text('Notify me before arrival'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        fixedSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({this.route, required this.active, this.onStopTap});

  final RouteModel? route;
  final bool active;
  final Function(double lat, double lng)? onStopTap;

  @override
  Widget build(BuildContext context) {
    final stops = route?.stops ?? [];

    return Container(
      decoration: _cardDecoration(radius: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Route Stops',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F0FF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.alt_route_rounded,
                        color: Color(0xFF0A6FE8),
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Live map',
                        style: TextStyle(
                          color: Color(0xFF0A6FE8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (stops.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No route stops loaded.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            )
          else
            for (var index = 0; index < stops.length; index++)
              _TimelineItem(
                stop: _RouteStop(
                  stops[index]['name'] ?? 'Stop',
                  'Stop ${stops[index]['sequence'] ?? index}',
                  active,
                  isCurrent: false,
                  lat: stops[index]['lat'] != null
                      ? (stops[index]['lat'] as num).toDouble()
                      : null,
                  lng: stops[index]['lng'] != null
                      ? (stops[index]['lng'] as num).toDouble()
                      : null,
                ),
                isFirst: index == 0,
                isLast: index == stops.length - 1,
                onTap: onStopTap,
              ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final _RouteStop stop;
  final bool isFirst;
  final bool isLast;
  final Function(double lat, double lng)? onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = stop.lat != null && stop.lng != null;
    return InkWell(
      onTap: canTap ? () => onTap?.call(stop.lat!, stop.lng!) : null,
      child: Container(
        height: 58,
        color: stop.isCurrent ? const Color(0xFFF8FBFF) : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: isFirst ? 29 : 0,
                    bottom: isLast ? 29 : 0,
                    child: Container(width: 2, color: const Color(0xFFD0D5DD)),
                  ),
                  _TimelineDot(
                    completed: stop.completed,
                    current: stop.isCurrent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: stop.isCurrent
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: stop.isCurrent ? 17 : 15,
                          fontWeight: stop.isCurrent
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      stop.time,
                      style: TextStyle(
                        color: stop.isCurrent
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: stop.isCurrent
                            ? FontWeight.w900
                            : FontWeight.w600,
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

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.completed, required this.current});

  final bool completed;
  final bool current;

  @override
  Widget build(BuildContext context) {
    if (current) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF0A6FE8),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: Colors.white,
          size: 15,
        ),
      );
    }

    return Container(
      width: completed ? 22 : 13,
      height: completed ? 22 : 13,
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFEAF8EF) : const Color(0xFFD0D5DD),
        shape: BoxShape.circle,
        border: completed
            ? Border.all(color: AppColors.success, width: 2)
            : null,
      ),
      child: completed
          ? const Icon(Icons.check_rounded, color: AppColors.success, size: 15)
          : null,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F101828), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

class _RouteStop {
  const _RouteStop(
    this.name,
    this.time,
    this.completed, {
    this.isCurrent = false,
    this.lat,
    this.lng,
  });

  final String name;
  final String time;
  final bool completed;
  final bool isCurrent;
  final double? lat;
  final double? lng;
}
