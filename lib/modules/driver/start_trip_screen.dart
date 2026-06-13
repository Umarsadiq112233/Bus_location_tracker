import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/services/location_service.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:bus_location_tracker/core/widgets/app_screen.dart';
import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = const LocationService();
  final AuthService _authService = AuthService();

  StreamSubscription<Position>? _positionSub;
  Timer? _simulationTimer;
  int _simulationIndex = 0;
  bool _isSimulating = false;
  LatLng? _currentDriverLocation;
  double _currentSpeed = 0.0;
  bool _isTripActive = false;
  bool _isMapReady = false;

  String? _currentTripId;
  DateTime? _tripStartTime;

  RouteModel? _route;
  List<LatLng> _roadPolyline = [];
  bool _loadingRoadRoute = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _route == null) {
      _route = args['route'] as RouteModel?;
      if (_route != null) {
        _loadRoadRoute(_route!);
      }
    }
  }

  Future<void> _loadRoadRoute(RouteModel route) async {
    final straightPoints = route.getPolylinePoints();
    if (straightPoints.length < 2) {
      setState(() {
        _roadPolyline = straightPoints;
        _loadingRoadRoute = false;
      });
      return;
    }

    try {
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
          final List<LatLng> roadPoints = coordinates.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
          setState(() {
            _roadPolyline = roadPoints;
            _loadingRoadRoute = false;
          });
          return;
        }
      }
    } catch (e) {
      // Fallback
    }

    setState(() {
      _roadPolyline = straightPoints;
      _loadingRoadRoute = false;
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _simulationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _showProfileRequiredDialog() {
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
          'Your phone number and driver license number are required to start a trip.\n\nPlease complete your profile credentials first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.editProfile).then((_) {
                // If they navigate back, the dashboard might have updated it,
                // but for double-safety we just let them go back.
              });
            },
            child: const Text('Update Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrip(
    BusModel bus,
    RouteModel route,
    UserModel? driver,
  ) async {
    if (driver != null) {
      if (driver.phone.trim().isEmpty ||
          driver.licenseNumber == null ||
          driver.licenseNumber!.trim().isEmpty) {
        _showProfileRequiredDialog();
        return;
      }
    }

    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to start a trip.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    setState(() {
      _isTripActive = true;
      _tripStartTime = DateTime.now();
    });

    // Create a new trip record in Firestore
    try {
      final tripDoc = FirebaseFirestore.instance.collection('trips').doc();
      _currentTripId = tripDoc.id;
      await tripDoc.set({
        'id': _currentTripId,
        'busId': bus.id,
        'busNumber': bus.busNumber,
        'routeId': route.id,
        'routeName': route.name,
        'driverId': driver?.uid ?? '',
        'driverName': driver?.name ?? 'Driver',
        'status': 'active',
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'stopsCount': route.stops?.length ?? 0,
        'duration': '',
      });
    } catch (e) {
      debugPrint('Error starting trip record: $e');
    }

    // Send Real-time Notification to Parents
    NotificationService().sendTripNotification(
      busId: bus.id,
      title: 'Bus Started',
      body: 'Bus ${bus.busNumber} has started its route ${route.name}.',
      type: 'bus_started',
    );

    // Start location updates stream
    _positionSub = _locationService.positionStream().listen(
      (position) {
        final point = LatLng(position.latitude, position.longitude);
        final speedKmh = position.speed * 3.6; // Convert m/s to km/h

        if (!mounted) return;
        setState(() {
          _currentDriverLocation = point;
          _currentSpeed = speedKmh;
        });

        // Push updates to Firestore
        final driver = _authService.currentUser;
        if (driver != null) {
          _authService.updateBusLocation(
            busId: bus.id,
            driverId: driver.uid,
            lat: position.latitude,
            lng: position.longitude,
            speed: speedKmh,
            status: 'active',
          );
        }

        if (_isMapReady) {
          _mapController.move(point, 16.0);
        }
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS Error: $error'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
    );
  }

  Future<void> _startSimulation(BusModel bus, RouteModel route) async {
    final points = _roadPolyline.isNotEmpty
        ? _roadPolyline
        : (route.getPolylinePoints());
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot start simulation: Route coordinates are empty.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    _simulationTimer?.cancel();
    _positionSub?.cancel(); // Cancel real GPS stream while simulating

    setState(() {
      _isSimulating = true;
      _isTripActive = true;
      _simulationIndex = 0;
      _currentDriverLocation = points.first;
      _currentSpeed = 35.0; // Simulated constant speed
      _tripStartTime = DateTime.now();
    });

    // Create a new trip record in Firestore (Simulated)
    try {
      final tripDoc = FirebaseFirestore.instance.collection('trips').doc();
      _currentTripId = tripDoc.id;
      await tripDoc.set({
        'id': _currentTripId,
        'busId': bus.id,
        'busNumber': bus.busNumber,
        'routeId': route.id,
        'routeName': route.name,
        'driverId': _authService.currentUser?.uid ?? '',
        'driverName': 'Driver',
        'status': 'active',
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'stopsCount': route.stops?.length ?? 0,
        'duration': '',
      });
    } catch (e) {
      debugPrint('Error starting trip record: $e');
    }

    // Send Real-time Notification to Parents (Simulated)
    NotificationService().sendTripNotification(
      busId: bus.id,
      title: 'Bus Started',
      body:
          'Bus ${bus.busNumber} has started its route ${route.name} (Simulated).',
      type: 'bus_started',
    );

    // Update initial location in Firestore
    final driver = _authService.currentUser;
    if (driver != null) {
      _authService.updateBusLocation(
        busId: bus.id,
        driverId: driver.uid,
        lat: points.first.latitude,
        lng: points.first.longitude,
        speed: 35.0,
        status: 'active',
      );
    }

    if (_isMapReady) {
      _mapController.move(points.first, 15.5);
    }

    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _simulationIndex = (_simulationIndex + 1) % points.length;
        _currentDriverLocation = points[_simulationIndex];
        // Generate a random-ish speed between 25 and 45 km/h for realism
        _currentSpeed = 25.0 + (math.Random().nextDouble() * 20.0);
      });

      final currentPoint = points[_simulationIndex];
      final driver = _authService.currentUser;
      if (driver != null) {
        _authService.updateBusLocation(
          busId: bus.id,
          driverId: driver.uid,
          lat: currentPoint.latitude,
          lng: currentPoint.longitude,
          speed: _currentSpeed,
          status: 'active',
        );
      }

      if (_isMapReady) {
        _mapController.move(currentPoint, 15.5);
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
    });
  }

  Future<void> _endTrip(BusModel bus, RouteModel route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text(
          'Are you sure you want to end this active trip and stop live sharing?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _positionSub?.cancel();
      _simulationTimer?.cancel();
      await _authService.endBusTrip(bus.id);

      // Update the trip record in Firestore
      if (_currentTripId != null) {
        try {
          final now = DateTime.now();
          final durationMinutes = _tripStartTime != null
              ? now.difference(_tripStartTime!).inMinutes
              : 25;
          final durationStr = '$durationMinutes min';

          await FirebaseFirestore.instance
              .collection('trips')
              .doc(_currentTripId)
              .update({
                'status': 'completed',
                'endTime': FieldValue.serverTimestamp(),
                'duration': durationStr,
              });
        } catch (e) {
          debugPrint('Error ending trip record: $e');
        }
      }

      // Send Real-time Notification to Parents (Reached School)
      NotificationService().sendTripNotification(
        busId: bus.id,
        title: 'Reached School',
        body: 'Bus ${bus.busNumber} has arrived at the school safely.',
        type: 'reached_school',
      );

      if (mounted) {
        setState(() {
          _isTripActive = false;
          _isSimulating = false;
          _currentDriverLocation = null;
          _currentSpeed = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip ended. Location sharing turned off.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final scheme = Theme.of(context).colorScheme;

    if (args == null || args['bus'] == null || args['route'] == null) {
      return AppScreen(
        title: 'Start Trip',
        subtitle: 'Loading details...',
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'Invalid arguments passed. Please go back and retry.',
                ),
              ),
            ),
          ),
        ],
      );
    }

    final BusModel bus = args['bus'];
    final RouteModel route = args['route'];
    final UserModel? driver = args['driver'];
    final polylinePoints = _roadPolyline.isNotEmpty
        ? _roadPolyline
        : route.getPolylinePoints();
    final startLatLng = route.startLat != null && route.startLng != null
        ? LatLng(route.startLat!, route.startLng!)
        : const LatLng(24.8607, 67.0011);
    final endLatLng = route.endLat != null && route.endLng != null
        ? LatLng(route.endLat!, route.endLng!)
        : const LatLng(24.8607, 67.0011);

    // Initial center is start position, or driver position if active
    final initialCenter = _currentDriverLocation ?? startLatLng;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Start Trip Tracker'),
            pinned: true,
            actions: [
              if (_isTripActive)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isSimulating
                              ? Colors.orange
                              : AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSimulating ? 'SIMULATION' : 'LIVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isSimulating
                              ? Colors.orange
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Map Container
                  Container(
                    height: 380,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: initialCenter,
                            initialZoom: 14.5,
                            onMapReady: () {
                              _isMapReady = true;
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.buslocationtracker.app',
                            ),
                            if (polylinePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: polylinePoints,
                                    color: _isTripActive
                                        ? scheme.primary.withValues(alpha: 0.85)
                                        : Colors.grey.withValues(alpha: 0.7),
                                    strokeWidth: 5.5,
                                    borderStrokeWidth: 1.5,
                                    borderColor: Colors.white,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                // Start Marker
                                Marker(
                                  point: startLatLng,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.trip_origin,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                // End Marker
                                Marker(
                                  point: endLatLng,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                // Intermediate Stops Markers
                                if (route.stops != null)
                                  for (var stop in route.stops!)
                                    if (stop['lat'] != null &&
                                        stop['lng'] != null)
                                      Marker(
                                        point: LatLng(
                                          (stop['lat'] as num).toDouble(),
                                          (stop['lng'] as num).toDouble(),
                                        ),
                                        width: 32,
                                        height: 32,
                                        child: CircleAvatar(
                                          backgroundColor: scheme.secondary,
                                          foregroundColor: Colors.white,
                                          child: Text(
                                            '${stop['sequence'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                // Current Live Driver Marker
                                if (_currentDriverLocation != null)
                                  Marker(
                                    point: _currentDriverLocation!,
                                    width: 44,
                                    height: 44,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            color: Colors.blueAccent,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (_loadingRoadRoute)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.15),
                              child: Center(
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                      vertical: 16.0,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Calculating road route...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Recenter Button
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            heroTag: 'recenterTripBtn',
                            backgroundColor: scheme.surface,
                            foregroundColor: scheme.primary,
                            onPressed: () {
                              final centerPoint =
                                  _currentDriverLocation ?? startLatLng;
                              _mapController.move(centerPoint, 15.5);
                            },
                            child: const Icon(Icons.my_location),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detail Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.directions_bus_rounded,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bus ${bus.busNumber}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Plate: ${bus.plateNumber}',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _isTripActive
                                      ? AppColors.success.withValues(
                                          alpha: 0.15,
                                        )
                                      : scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _isTripActive ? 'ACTIVE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: _isTripActive
                                        ? AppColors.success
                                        : scheme.onErrorContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _StatsColumn(
                                  label: 'Route Name',
                                  value: route.name,
                                  icon: Icons.alt_route,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: scheme.outlineVariant,
                              ),
                              Expanded(
                                child: _StatsColumn(
                                  label: 'Current Speed',
                                  value:
                                      '${_currentSpeed.toStringAsFixed(1)} km/h',
                                  icon: Icons.speed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  if (!_isTripActive) ...[
                    ElevatedButton.icon(
                      onPressed: () => _startTrip(bus, route, driver),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Trip (Real GPS)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _startSimulation(bus, route),
                      icon: const Icon(Icons.route_rounded),
                      label: const Text('Start Simulated Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    if (_isSimulating) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          _stopSimulation();
                          _endTrip(bus, route);
                        },
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop Simulation & End Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () => _endTrip(bus, route),
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('End Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsColumn extends StatelessWidget {
  const _StatsColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}
