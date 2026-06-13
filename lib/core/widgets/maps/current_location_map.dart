import 'dart:async';
import 'package:bus_location_tracker/app/theme/app_colors.dart';

import 'package:bus_location_tracker/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

typedef LocationSnapshotChanged = void Function(CurrentLocationSnapshot value);

class CurrentLocationSnapshot {
  const CurrentLocationSnapshot({
    required this.point,
    required this.position,
    this.address,
  });

  final LatLng point;
  final Position position;
  final LocationAddress? address;
}

class CurrentLocationMap extends StatefulWidget {
  const CurrentLocationMap({
    super.key,
    this.initialCenter = const LatLng(24.9042, 67.0768),
    this.initialZoom = 16,
    this.recenterButtonBottom = 338,
    this.showAttribution = true,
    this.onLocationChanged,
    this.busLocation,
    this.routePoints,
    this.stops,
    this.mapController,
    this.showControls = true,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final double recenterButtonBottom;
  final bool showAttribution;
  final LocationSnapshotChanged? onLocationChanged;
  final LatLng? busLocation;
  final List<LatLng>? routePoints;
  final List<dynamic>? stops;
  final MapController? mapController;
  final bool showControls;

  @override
  State<CurrentLocationMap> createState() => _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<CurrentLocationMap> {
  final _locationService = const LocationService();
  late final MapController _mapController;

  StreamSubscription<Position>? _positionSub;
  LatLng? _currentLocation;
  LatLng? _lastAddressPoint;
  LocationAddress? _lastAddress;
  late _MapLoadState _state;
  String? _message;
  bool _mapReady = false;
  int _addressLookupId = 0;
  bool _hasFittedInitial = false;

  @override
  void initState() {
    super.initState();
    final hasRoute = (widget.routePoints != null && widget.routePoints!.isNotEmpty) || widget.busLocation != null;
    _state = hasRoute ? _MapLoadState.ready : _MapLoadState.loading;
    _mapController = widget.mapController ?? MapController();
    _loadCurrentLocation();
  }

  @override
  void didUpdateWidget(covariant CurrentLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady) {
      final oldRouteEmpty = oldWidget.routePoints == null || oldWidget.routePoints!.isEmpty;
      final newRouteNotEmpty = widget.routePoints != null && widget.routePoints!.isNotEmpty;

      final oldBusNull = oldWidget.busLocation == null;
      final newBusNotNull = widget.busLocation != null;

      if ((oldRouteEmpty && newRouteNotEmpty) || (oldBusNull && newBusNotNull) || !_hasFittedInitial) {
        final hasRoute = (widget.routePoints != null && widget.routePoints!.isNotEmpty) || widget.busLocation != null;
        if (hasRoute) {
          _hasFittedInitial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitRouteAndBus();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    if (widget.mapController == null) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _fitRouteAndBus() {
    if (!_mapReady) return;
    final List<LatLng> points = [];
    if (widget.busLocation != null) {
      points.add(widget.busLocation!);
    }
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      points.addAll(widget.routePoints!);
    }
    if (widget.stops != null) {
      for (var stop in widget.stops!) {
        if (stop is Map && stop['lat'] != null && stop['lng'] != null) {
          points.add(LatLng((stop['lat'] as num).toDouble(), (stop['lng'] as num).toDouble()));
        }
      }
    }
    if (points.isNotEmpty) {
      if (points.length > 1) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: EdgeInsets.only(
              left: widget.showControls ? 50.0 : 20.0,
              right: widget.showControls ? 50.0 : 20.0,
              top: widget.showControls ? 50.0 : 20.0,
              bottom: widget.showControls ? 220.0 : 20.0,
            ),
          ),
        );
      } else {
        _moveTo(points.first);
      }
    } else if (_currentLocation != null) {
      _moveTo(_currentLocation!);
    }
  }

  Future<void> _loadCurrentLocation({bool forceMove = false}) async {
    final hasRoute = (widget.routePoints != null && widget.routePoints!.isNotEmpty) || widget.busLocation != null;
    final shouldMove = forceMove || !hasRoute;

    if (!hasRoute) {
      setState(() {
        _state = _MapLoadState.loading;
        _message = null;
      });
    }

    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return;

      if (position == null) {
        if (hasRoute) {
          setState(() {
            _state = _MapLoadState.ready;
          });
          return;
        }
        setState(() {
          _state = _MapLoadState.permissionDenied;
          _message =
              'Location permission is required to show your current position.';
        });
        return;
      }

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = point;
        _state = _MapLoadState.ready;
      });
      if (shouldMove) {
        _moveTo(point);
      }
      _publishLocation(position, point);
      _listenToLocationUpdates(forceMove: forceMove);
    } catch (_) {
      if (!mounted) return;
      if (hasRoute) {
        setState(() {
          _state = _MapLoadState.ready;
        });
        return;
      }
      setState(() {
        _state = _MapLoadState.error;
        _message = 'Unable to get your current location. Please try again.';
      });
    }
  }

  void _listenToLocationUpdates({bool forceMove = false}) {
    final hasRoute = (widget.routePoints != null && widget.routePoints!.isNotEmpty) || widget.busLocation != null;
    final shouldMove = forceMove || !hasRoute;

    _positionSub?.cancel();
    _positionSub = _locationService.positionStream().listen(
      (position) {
        final point = LatLng(position.latitude, position.longitude);
        if (!mounted) return;
        setState(() => _currentLocation = point);
        if (shouldMove) {
          _moveTo(point);
        }
        _publishLocation(position, point);
      },
      onError: (_) {
        if (!mounted) return;
        if (hasRoute) return;
        setState(() {
          _state = _MapLoadState.error;
          _message = 'Live location tracking stopped. Tap retry to continue.';
        });
      },
    );
  }

  void _moveTo(LatLng point) {
    if (!_mapReady) return;
    _mapController.move(point, widget.initialZoom);
  }

  Future<void> _openSettings() async {
    await _locationService.openAppLocationSettings();
  }

  void _publishLocation(Position position, LatLng point) {
    widget.onLocationChanged?.call(
      CurrentLocationSnapshot(
        point: point,
        position: position,
        address: _lastAddress,
      ),
    );

    if (!_shouldLookupAddress(point)) return;
    final lookupId = ++_addressLookupId;

    _locationService.reverseGeocode(position).then((address) {
      if (!mounted || lookupId != _addressLookupId || address == null) {
        return;
      }

      _lastAddressPoint = point;
      _lastAddress = address;
      widget.onLocationChanged?.call(
        CurrentLocationSnapshot(
          point: point,
          position: position,
          address: address,
        ),
      );
    });
  }

  bool _shouldLookupAddress(LatLng point) {
    if (_lastAddressPoint == null || _lastAddress == null) return true;

    final meters = Geolocator.distanceBetween(
      _lastAddressPoint!.latitude,
      _lastAddressPoint!.longitude,
      point.latitude,
      point.longitude,
    );
    return meters >= 80;
  }

  @override
  Widget build(BuildContext context) {
    final point = _currentLocation ?? widget.busLocation ?? widget.initialCenter;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: point,
            initialZoom: widget.initialZoom,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;
              final hasRoute = (widget.routePoints != null && widget.routePoints!.isNotEmpty) || widget.busLocation != null;
              if (hasRoute) {
                _hasFittedInitial = true;
                _fitRouteAndBus();
              } else if (_currentLocation != null) {
                _moveTo(_currentLocation!);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.buslocationtracker.app',
            ),
            if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints!,
                    color: AppColors.primary.withValues(alpha: 0.8),
                    strokeWidth: 5.0,
                    borderStrokeWidth: 1.5,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            if (widget.stops != null)
              MarkerLayer(
                markers: [
                  for (var stop in widget.stops!)
                    if (stop['lat'] != null && stop['lng'] != null)
                      Marker(
                        point: LatLng((stop['lat'] as num).toDouble(), (stop['lng'] as num).toDouble()),
                        width: 30,
                        height: 30,
                        child: CircleAvatar(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          radius: 12,
                          child: Text(
                            '${stop['sequence'] ?? ''}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                ],
              ),
            if (_currentLocation != null) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentLocation!,
                    radius: 42,
                    color: AppColors.primary.withValues(alpha: .16),
                    borderColor: AppColors.primary.withValues(alpha: .25),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 54,
                    height: 54,
                    child: const _UserLocationMarker(),
                  ),
                ],
              ),
            ],
            if (widget.busLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.busLocation!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_rounded,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_state == _MapLoadState.loading)
          const _MapStatusOverlay.loading()
        else if (_state == _MapLoadState.permissionDenied)
          _MapStatusOverlay(
            icon: Icons.location_off_rounded,
            title: 'Location permission needed',
            message: _message!,
            actionLabel: 'Open settings',
            onAction: _openSettings,
          )
        else if (_state == _MapLoadState.error)
          _MapStatusOverlay(
            icon: Icons.error_outline_rounded,
            title: 'Location unavailable',
            message: _message!,
            actionLabel: 'Retry',
            onAction: () => _loadCurrentLocation(),
          ),
        if (widget.showControls) ...[
          Positioned(
            right: 18,
            bottom: widget.recenterButtonBottom + 58,
            child: _MapFloatingButton(
              icon: Icons.directions_bus_rounded,
              onTap: _fitRouteAndBus,
            ),
          ),
          Positioned(
            right: 18,
            bottom: widget.recenterButtonBottom,
            child: _MapFloatingButton(
              icon: Icons.my_location_rounded,
              onTap: () => _loadCurrentLocation(forceMove: true),
            ),
          ),
        ],
        if (widget.showAttribution)
          const Positioned(left: 12, bottom: 14, child: _OsmAttribution()),
      ],
    );
  }
}

enum _MapLoadState { loading, ready, permissionDenied, error }

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 5,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }
}

class _MapStatusOverlay extends StatelessWidget {
  const _MapStatusOverlay({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  const _MapStatusOverlay.loading()
    : icon = Icons.location_searching_rounded,
      title = 'Finding your location',
      message = 'Please wait while we get your current GPS position.',
      actionLabel = null,
      onAction = null;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .16),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 250;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Container(
                  margin: EdgeInsets.all(isCompact ? 10 : 20),
                  padding: EdgeInsets.all(isCompact ? 12 : 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 18),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: AppColors.primary, size: isCompact ? 28 : 34),
                        SizedBox(height: isCompact ? 6 : 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isCompact ? 14 : 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: isCompact ? 4 : 6),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF52626D),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        if (actionLabel == null) ...[
                          SizedBox(height: isCompact ? 10 : 14),
                          SizedBox(
                            width: isCompact ? 18 : 22,
                            height: isCompact ? 18 : 22,
                            child: const CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ] else ...[
                          SizedBox(height: isCompact ? 10 : 14),
                          SizedBox(
                            height: isCompact ? 36 : null,
                            child: FilledButton(
                              onPressed: onAction,
                              style: isCompact
                                  ? FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    )
                                  : null,
                              child: Text(actionLabel!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 10, color: Color(0xFF52626D)),
        ),
      ),
    );
  }
}
