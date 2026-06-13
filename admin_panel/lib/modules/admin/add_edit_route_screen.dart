import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/route_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class AddEditRouteScreen extends StatefulWidget {
  const AddEditRouteScreen({super.key});

  @override
  State<AddEditRouteScreen> createState() => _AddEditRouteScreenState();
}

enum SelectionMode { start, stop, end }

class _AddEditRouteScreenState extends State<AddEditRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routeNameController = TextEditingController();
  final _startNameController = TextEditingController();
  final _endNameController = TextEditingController();

  LatLng? _startLatLng;
  LatLng? _endLatLng;

  // Intermediate stops: list of map structures:
  // { 'lat': double, 'lng': double, 'controller': TextEditingController }
  final List<Map<String, dynamic>> _stops = [];

  SelectionMode _currentMode = SelectionMode.start;
  bool _isLoading = false;
  List<LatLng> _roadPolylinePoints = [];

  Future<void> _updateRoadRoute() async {
    final List<LatLng> points = [];
    if (_startLatLng != null) points.add(_startLatLng!);
    for (final stop in _stops) {
      points.add(LatLng(stop['lat'], stop['lng']));
    }
    if (_endLatLng != null) points.add(_endLatLng!);

    if (points.length < 2) {
      setState(() => _roadPolylinePoints = points);
      return;
    }

    try {
      final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson'
      );
      final response = await http.get(url, headers: {'User-Agent': 'com.blt.admin_panel'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final List<dynamic> coordinates = geometry['coordinates'];
          final List<LatLng> roadPoints = coordinates.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
          setState(() {
            _roadPolylinePoints = roadPoints;
          });
          return;
        }
      }
    } catch (e) {
      // Fallback
    }
    setState(() => _roadPolylinePoints = points);
  }

  final MapController _mapController = MapController();
  static const LatLng _karachiCenter = LatLng(24.8607, 67.0011);

  // Search state
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    _routeNameController.dispose();
    _startNameController.dispose();
    _endNameController.dispose();
    for (final stop in _stops) {
      (stop['controller'] as TextEditingController).dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  void _addStop(LatLng point) {
    setState(() {
      final index = _stops.length + 1;
      final controller = TextEditingController(text: 'Stop $index');
      _stops.add({
        'lat': point.latitude,
        'lng': point.longitude,
        'controller': controller,
      });
    });
    _updateRoadRoute();
  }

  void _moveStopUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _stops[index];
        _stops[index] = _stops[index - 1];
        _stops[index - 1] = temp;
      });
      _updateRoadRoute();
    }
  }

  void _moveStopDown(int index) {
    if (index < _stops.length - 1) {
      setState(() {
        final temp = _stops[index];
        _stops[index] = _stops[index + 1];
        _stops[index + 1] = temp;
      });
      _updateRoadRoute();
    }
  }

  void _deleteStop(int index) {
    setState(() {
      (_stops[index]['controller'] as TextEditingController).dispose();
      _stops.removeAt(index);
    });
    _updateRoadRoute();
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      switch (_currentMode) {
        case SelectionMode.start:
          _startLatLng = latLng;
          break;
        case SelectionMode.end:
          _endLatLng = latLng;
          break;
        case SelectionMode.stop:
          _addStop(latLng);
          return;
      }
    });
    _updateRoadRoute();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching current location...')),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5');
      final response = await http.get(url, headers: {'User-Agent': 'com.blt.admin_panel'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _searchResults = data;
            _isSearching = false;
          });
        }
      } else {
        throw Exception('Failed to load search results');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _onSearchResultSelected(dynamic place) {
    final lat = double.parse(place['lat'].toString());
    final lon = double.parse(place['lon'].toString());
    _mapController.move(LatLng(lat, lon), 14.0);
    setState(() {
      _showSearchResults = false;
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  void _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map to set a Start Location.'),
        ),
      );
      return;
    }
    if (_endLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map to set an End Location.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stopsData = _stops.map((stop) {
        final ctrl = stop['controller'] as TextEditingController;
        return {
          'name': ctrl.text.trim().isEmpty ? 'Unnamed Stop' : ctrl.text.trim(),
          'lat': stop['lat'],
          'lng': stop['lng'],
        };
      }).toList();

      await RouteService().saveRoute(
        name: _routeNameController.text.trim(),
        startName: _startNameController.text.trim().isEmpty
            ? 'Start Point'
            : _startNameController.text.trim(),
        startLat: _startLatLng!.latitude,
        startLng: _startLatLng!.longitude,
        endName: _endNameController.text.trim().isEmpty
            ? 'End Point'
            : _endNameController.text.trim(),
        endLat: _endLatLng!.latitude,
        endLng: _endLatLng!.longitude,
        stops: stopsData,
        status: 'active',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 950;

    // Helper message based on selection mode
    String helpMsg = '';
    switch (_currentMode) {
      case SelectionMode.start:
        helpMsg = 'Tap the map to set the Start Location (Green Marker)';
        break;
      case SelectionMode.stop:
        helpMsg = 'Tap the map to add sequencing Stops (Blue Markers)';
        break;
      case SelectionMode.end:
        helpMsg = 'Tap the map to set the End Location (Red Marker)';
        break;
    }

    // List of LatLngs for Polyline
    final List<LatLng> polylinePoints = _roadPolylinePoints;

    // Right-side Map Widget
    Widget buildMap() {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _karachiCenter,
                initialZoom: 12.0,
                onTap: _handleMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.buslocationtracker.app',
                ),
                if (polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        color: scheme.primary.withValues(alpha: 0.8),
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_startLatLng != null)
                      Marker(
                        point: _startLatLng!,
                        width: 80,
                        height: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.trip_origin_rounded,
                              color: Colors.green,
                              size: 30,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'START',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (int i = 0; i < _stops.length; i++)
                      Marker(
                        point: LatLng(_stops[i]['lat'], _stops[i]['lng']),
                        width: 80,
                        height: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.blue,
                              size: 30,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Stop ${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_endLatLng != null)
                      Marker(
                        point: _endLatLng!,
                        width: 80,
                        height: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              color: Colors.red,
                              size: 30,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'END',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // Floating instruction banner
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: scheme.surface.withValues(alpha: 0.95),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          helpMsg,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Search Bar & Results
            Positioned(
              top: 70,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search places...',
                                border: InputBorder.none,
                              ),
                              onSubmitted: _searchPlace,
                            ),
                          ),
                          if (_isSearching)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showSearchResults = false;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Card(
                      elevation: 4,
                      color: scheme.surface,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(place['display_name'] ?? 'Unknown location', maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () => _onSearchResultSelected(place),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            // Current Location FAB
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'currentLocationFab',
                onPressed: _getCurrentLocation,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      );
    }

    // Left-side controls and stops list
    Widget buildLeftPane() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Route Name Field
            CustomTextField(
              label: 'Route Name',
              icon: Icons.alt_route_rounded,
              controller: _routeNameController,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter route name'
                  : null,
            ),
            const SizedBox(height: 12),

            // Start & End Name Fields
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Start Stop Name',
                    icon: Icons.trip_origin_rounded,
                    controller: _startNameController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter start name'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    label: 'End Stop Name',
                    icon: Icons.place_rounded,
                    controller: _endNameController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter end name'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interactive Selector Mode
            Text(
              'Map Point Selection Mode:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Start Point',
                    icon: Icons.trip_origin_rounded,
                    color: Colors.green,
                    isSelected: _currentMode == SelectionMode.start,
                    onPressed: () =>
                        setState(() => _currentMode = SelectionMode.start),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ModeButton(
                    label: 'Add Stop',
                    icon: Icons.location_on_rounded,
                    color: Colors.blue,
                    isSelected: _currentMode == SelectionMode.stop,
                    onPressed: () =>
                        setState(() => _currentMode = SelectionMode.stop),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ModeButton(
                    label: 'End Point',
                    icon: Icons.place_rounded,
                    color: Colors.red,
                    isSelected: _currentMode == SelectionMode.end,
                    onPressed: () =>
                        setState(() => _currentMode = SelectionMode.end),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Coordinates Indicators
            Row(
              children: [
                Expanded(
                  child: _CoordinateCard(
                    title: 'Start Location',
                    latLng: _startLatLng,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CoordinateCard(
                    title: 'End Location',
                    latLng: _endLatLng,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Intermediate Stops Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stops Sequence (${_stops.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_stops.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final s in _stops) {
                          (s['controller'] as TextEditingController).dispose();
                        }
                        _stops.clear();
                      });
                      _updateRoadRoute();
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Intermediate Stops List
            Expanded(
              child: _stops.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 36,
                              color: scheme.primary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No stops added yet.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the map in "Add Stop" mode to place picking/dropping points.',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _stops.length,
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        final ctrl =
                            stop['controller'] as TextEditingController;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: ctrl,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                        ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        'Lat: ${stop['lat'].toStringAsFixed(5)}, Lng: ${stop['lng'].toStringAsFixed(5)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                  onPressed: index == 0
                                      ? null
                                      : () => _moveStopUp(index),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                  onPressed: index == _stops.length - 1
                                      ? null
                                      : () => _moveStopDown(index),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () => _deleteStop(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Save & Cancel buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    label: _isLoading ? 'Saving...' : 'Save Route',
                    icon: _isLoading ? null : Icons.save_rounded,
                    onPressed: _isLoading ? () {} : _saveRoute,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Main build layout containing Left Pane and Right Map
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Route Path'),
            Text(
              'Design route paths on the map and configure intermediate pick/drop stops.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving Route & Sequenced Stops to Firestore...'),
                    ],
                  ),
                )
              : isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 420, child: buildLeftPane()),
                    const SizedBox(width: 16),
                    Expanded(child: buildMap()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: buildMap()),
                    const SizedBox(height: 16),
                    Expanded(flex: 5, child: buildLeftPane()),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : scheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinateCard extends StatelessWidget {
  const _CoordinateCard({
    required this.title,
    required this.latLng,
    required this.color,
  });

  final String title;
  final LatLng? latLng;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  latLng != null
                      ? Icons.check_circle_rounded
                      : Icons.help_outline_rounded,
                  color: latLng != null
                      ? color
                      : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    latLng != null
                        ? '${latLng!.latitude.toStringAsFixed(4)}, ${latLng!.longitude.toStringAsFixed(4)}'
                        : 'Tap map to set',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: latLng != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: latLng != null
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
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
