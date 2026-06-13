import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as permissions;

class LocationAddress {
  const LocationAddress({
    required this.displayName,
    required this.shortName,
    required this.city,
  });

  final String displayName;
  final String shortName;
  final String city;
}

class LocationService {
  const LocationService();

  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var status = await permissions.Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await permissions.Permission.locationWhenInUse.request();
    }

    if (status.isPermanentlyDenied) return false;
    if (!status.isGranted) return false;

    final geolocatorPermission = await Geolocator.checkPermission();
    if (geolocatorPermission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> openAppLocationSettings() {
    return permissions.openAppSettings();
  }

  Future<Position?> currentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      ),
    );
  }

  Future<LocationAddress?> reverseGeocode(Position position) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toStringAsFixed(7),
      'lon': position.longitude.toStringAsFixed(7),
      'zoom': '18',
      'addressdetails': '1',
    });

    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'BLT Bus Location Tracker Flutter App',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};
      final displayName = (data['display_name'] as String?)?.trim();
      final road = _firstText(address, const [
        'road',
        'pedestrian',
        'footway',
        'neighbourhood',
        'suburb',
        'quarter',
      ]);
      final city = _firstText(address, const [
        'city',
        'town',
        'municipality',
        'county',
        'state',
      ]);
      final shortName = [
        road,
        city,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

      if ((displayName == null || displayName.isEmpty) && shortName.isEmpty) {
        return null;
      }

      return LocationAddress(
        displayName: displayName ?? shortName,
        shortName: shortName.isEmpty ? displayName! : shortName,
        city: city ?? 'Nearby area',
      );
    } catch (_) {
      return null;
    }
  }

  String? _firstText(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
