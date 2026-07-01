import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/models/route_model.dart';
import '../../core/providers/admin_provider.dart';
import '../../core/widgets/app_screen.dart';

class AdminLiveTrackingScreen extends StatefulWidget {
  const AdminLiveTrackingScreen({super.key});

  @override
  State<AdminLiveTrackingScreen> createState() =>
      _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState extends State<AdminLiveTrackingScreen> {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(
    24.8607,
    67.0011,
  ); // Default to Karachi

  String? _selectedBusId;
  bool _isInit = false;
  Map<String, RouteModel> _routesMap = {};
  final Map<String, List<LatLng>> _roadRoutesCache = {};
  List<String>? _schoolBusIds; // Only set for SchoolAdmin

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadSchoolBusIds();
  }

  Future<void> _loadSchoolBusIds() async {
    // Only needed for SchoolAdmin
    final provider = context.read<AdminProvider>();
    if (provider.isSchoolAdmin && provider.schoolId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(provider.schoolId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _schoolBusIds = List<String>.from(doc.data()?['assignedBusIds'] ?? []);
          });
        } else if (mounted) {
          setState(() {
            _schoolBusIds = [];
          });
        }
      } catch (e) {
        debugPrint('Failed to load school bus IDs: $e');
        if (mounted) {
          setState(() {
            _schoolBusIds = [];
          });
        }
      }
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final qs = await FirebaseFirestore.instance.collection('routes').get();
      final map = <String, RouteModel>{};
      for (var doc in qs.docs) {
        map[doc.id] = RouteModel.fromMap(doc.data(), doc.id);
      }
      if (mounted) {
        setState(() => _routesMap = map);
      }
    } catch (e) {
      debugPrint('Failed to load routes: $e');
    }
  }

  Future<void> _fetchRoadRoute(RouteModel route) async {
    if (_roadRoutesCache.containsKey(route.id)) return;
    
    try {
      final List<LatLng> waypoints = [];
      if (route.startLat != null && route.startLng != null) {
        waypoints.add(LatLng(route.startLat!, route.startLng!));
      }
      if (route.stops != null) {
        for (var stop in route.stops!) {
          waypoints.add(LatLng(stop['lat'], stop['lng']));
        }
      }
      if (route.endLat != null && route.endLng != null) {
        waypoints.add(LatLng(route.endLat!, route.endLng!));
      }

      if (waypoints.length < 2) return;

      final coordinatesString = waypoints.map((wp) => '${wp.longitude},${wp.latitude}').join(';');
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordinatesString?overview=full&geometries=geojson');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final List<LatLng> routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          
          if (mounted) {
            setState(() {
              _roadRoutesCache[route.id] = routePoints;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch road route: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final busId = ModalRoute.of(context)?.settings.arguments as String?;
      if (busId != null && busId.isNotEmpty) {
        _selectedBusId = busId;
      }
      _isInit = true;
    }
  }

  void _focusOnBus(String busId, double lat, double lng) {
    setState(() {
      _selectedBusId = busId;
    });
    _mapController.move(LatLng(lat, lng), 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final provider = context.read<AdminProvider>();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('buses').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading live data'));
        }

        final docs = snapshot.data?.docs ?? [];
        var allBuses = docs.toList();

        // SchoolAdmin: filter to only school-assigned buses
        if (provider.isSchoolAdmin) {
          if (_schoolBusIds == null) {
            return AppScreen(
              title: 'Admin Live Tracking',
              subtitle: 'Monitor all active buses with real-time GPS locations.',
              children: const [
                SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            );
          }
          allBuses = allBuses.where((doc) => _schoolBusIds!.contains(doc.id)).toList();
        }

        final activeBuses = allBuses.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['currentLat'] != null && data['currentLng'] != null;
        }).toList();

        final offlineBuses = allBuses.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['currentLat'] == null || data['currentLng'] == null;
        }).toList();

        final List<Polyline> polylines = [];
        final List<Marker> extraMarkers = [];

        // Auto-focus on selected bus on init
        if (_selectedBusId != null && !_isInit) {
          final selectedBus = allBuses
              .where((b) => b.id == _selectedBusId)
              .firstOrNull;
          if (selectedBus != null) {
            final data = selectedBus.data() as Map<String, dynamic>;
            final lat = data['currentLat'] != null
                ? (data['currentLat'] as num).toDouble()
                : null;
            final lng = data['currentLng'] != null
                ? (data['currentLng'] as num).toDouble()
                : null;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (lat != null && lng != null) {
                _mapController.move(LatLng(lat, lng), 15.0);
              } else {
                // If offline, try to focus on route start
                final routeId = data['assignedRouteId'];
                if (routeId != null && _routesMap.containsKey(routeId)) {
                  final route = _routesMap[routeId]!;
                  if (route.startLat != null && route.startLng != null) {
                    _mapController.move(
                      LatLng(route.startLat!, route.startLng!),
                      14.0,
                    );
                  }
                }
              }
            });
            _isInit = true;
          }
        }

        // Draw polylines and extra markers for the selected bus
        if (_selectedBusId != null) {
          final selectedBus = allBuses
              .where((b) => b.id == _selectedBusId)
              .firstOrNull;
          if (selectedBus != null) {
            final data = selectedBus.data() as Map<String, dynamic>;
            final routeId = data['assignedRouteId'];
            final isActive =
                data['currentLat'] != null && data['currentLng'] != null;

            if (routeId != null && _routesMap.containsKey(routeId)) {
              final route = _routesMap[routeId]!;

              if (!_roadRoutesCache.containsKey(route.id)) {
                _fetchRoadRoute(route);
              }

              if (isActive) {
                final busLat = (data['currentLat'] as num).toDouble();
                final busLng = (data['currentLng'] as num).toDouble();
                if (route.endLat != null && route.endLng != null) {
                  final endPoint = LatLng(route.endLat!, route.endLng!);
                  
                  if (_roadRoutesCache.containsKey(route.id)) {
                    polylines.add(
                      Polyline(
                        points: _roadRoutesCache[route.id]!,
                        color: const Color(0xFF1976D2).withValues(alpha: 0.8), // Professional Blue
                        strokeWidth: 5.0,
                      ),
                    );
                  } else {
                    polylines.add(
                      Polyline(
                        points: [LatLng(busLat, busLng), endPoint],
                        color: const Color(0xFF1976D2),
                        strokeWidth: 5.0,
                        pattern: StrokePattern.dashed(segments: [10.0, 10.0]),
                      ),
                    );
                  }
                  extraMarkers.add(
                    Marker(
                      point: endPoint,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  );
                }
              } else {
                // Offline bus: Draw full route from start to end
                if (route.startLat != null &&
                    route.startLng != null &&
                    route.endLat != null &&
                    route.endLng != null) {
                  final startPoint = LatLng(route.startLat!, route.startLng!);
                  final endPoint = LatLng(route.endLat!, route.endLng!);
                  
                  List<LatLng> routePoints = [];
                  if (_roadRoutesCache.containsKey(route.id)) {
                     routePoints = _roadRoutesCache[route.id]!;
                  } else {
                     routePoints = [startPoint];
                     if (route.stops != null) {
                       for (var stop in route.stops!) {
                         routePoints.add(LatLng(stop['lat'], stop['lng']));
                       }
                     }
                     routePoints.add(endPoint);
                  }

                  polylines.add(
                    Polyline(
                      points: routePoints,
                      color: const Color(0xFF1976D2), // Professional Blue
                      strokeWidth: 5.0,
                      pattern: _roadRoutesCache.containsKey(route.id) 
                         ? const StrokePattern.solid() 
                         : StrokePattern.dashed(segments: [10.0, 10.0]),
                    ),
                  );
                  extraMarkers.add(
                    Marker(
                      point: startPoint,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.trip_origin,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  );
                  extraMarkers.add(
                    Marker(
                      point: endPoint,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  );
                }
              }
            }
          }
        }

        final List<Marker> markers = activeBuses.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lat = (data['currentLat'] as num).toDouble();
          final lng = (data['currentLng'] as num).toDouble();
          final busNum = data['busNumber'] ?? 'Bus';
          final plateNum = data['plateNumber'] ?? '';
          final routeId = data['assignedRouteId'];

          RouteModel? route;
          if (routeId != null && _routesMap.containsKey(routeId)) {
            route = _routesMap[routeId];
          }

          final isSelected = _selectedBusId == doc.id;

          return Marker(
            point: LatLng(lat, lng),
            width: isSelected ? 220 : 80,
            height: isSelected ? 160 : 80,
            child: GestureDetector(
              onTap: () => _focusOnBus(doc.id, lat, lng),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$busNum ($plateNum)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  route != null
                                      ? 'En route to ${route.endPoint}'
                                      : 'No route assigned',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        busNum,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.blueAccent,
                    size: 36,
                  ),
                ],
              ),
            ),
          );
        }).toList();

        Widget mapWidget = Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.buslocationtracker.app',
                  ),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: [...markers, ...extraMarkers]),
                ],
              ),
              // Live Indicator
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE: ${activeBuses.length} | OFFLINE: ${offlineBuses.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Back to default center button
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  heroTag: 'recenterMapBtn',
                  backgroundColor: scheme.surface,
                  foregroundColor: scheme.primary,
                  onPressed: () {
                    _mapController.move(_defaultCenter, 12.0);
                  },
                  child: const Icon(Icons.zoom_out_map),
                ),
              ),
            ],
          ),
        );

        Widget listWidget = Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Active Fleet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: allBuses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No buses found in the database.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: allBuses.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          // Sort active buses first, then offline
                          final sortedBuses = [...activeBuses, ...offlineBuses];
                          final doc = sortedBuses[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final busNum = data['busNumber'] ?? 'Unknown';
                          final lat = data['currentLat'] != null
                              ? (data['currentLat'] as num).toDouble()
                              : null;
                          final lng = data['currentLng'] != null
                              ? (data['currentLng'] as num).toDouble()
                              : null;
                          final speed = data['speed'] ?? 0;
                          final routeId = data['assignedRouteId'];
                          final isActive = lat != null && lng != null;

                          String routeText = 'No route assigned';
                          RouteModel? route;
                          if (routeId != null &&
                              _routesMap.containsKey(routeId)) {
                            route = _routesMap[routeId]!;
                            routeText =
                                '${route.startPoint} ➔ ${route.endPoint}';
                          }

                          final isSelected = _selectedBusId == doc.id;

                          Widget stopsWidget = const SizedBox.shrink();
                          if (isSelected &&
                              route != null &&
                              route.stops != null &&
                              route.stops!.isNotEmpty) {
                            stopsWidget = Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stops:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  ...route.stops!.map(
                                    (stop) => Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              stop['name'] ?? 'Stop',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: scheme.primaryContainer
                                .withValues(alpha: 0.3),
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? scheme.primaryContainer
                                  : Colors.grey.shade300,
                              child: Icon(
                                Icons.directions_bus,
                                color: isActive
                                    ? scheme.onPrimaryContainer
                                    : Colors.grey.shade600,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    busNum,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Offline',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isActive) Text('Speed: $speed km/h'),
                                const SizedBox(height: 2),
                                Text(
                                  routeText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive
                                        ? scheme.primary
                                        : Colors.grey,
                                  ),
                                ),
                                stopsWidget,
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isActive
                                    ? Icons.my_location_rounded
                                    : Icons.route_rounded,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _selectedBusId = doc.id);
                                if (isActive) {
                                  _mapController.move(
                                    LatLng(lat as double, lng as double),
                                    15.0,
                                  );
                                } else if (route != null &&
                                    route.startLat != null &&
                                    route.startLng != null) {
                                  _mapController.move(
                                    LatLng(route.startLat!, route.startLng!),
                                    14.0,
                                  );
                                }
                              },
                              tooltip: isActive ? 'Focus on Bus' : 'View Route',
                            ),
                            onTap: () {
                              setState(() => _selectedBusId = doc.id);
                              if (isActive) {
                                _mapController.move(
                                  LatLng(lat as double, lng as double),
                                  15.0,
                                );
                              } else if (route != null &&
                                  route.startLat != null &&
                                  route.startLng != null) {
                                _mapController.move(
                                  LatLng(route.startLat!, route.startLng!),
                                  14.0,
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );

        return AppScreen(
          title: 'Admin Live Tracking',
          subtitle: 'Monitor all active buses with real-time GPS locations.',
          children: [
            if (isWide)
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: mapWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: listWidget),
                  ],
                ),
              )
            else
              Column(
                children: [
                  SizedBox(height: 500, child: mapWidget),
                  const SizedBox(height: 16),
                  SizedBox(height: 400, child: listWidget),
                ],
              ),
          ],
        );
      },
    );
  }
}
