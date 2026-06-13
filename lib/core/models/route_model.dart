import 'package:latlong2/latlong.dart';

class RouteModel {
  final String id;
  final String name;
  final String startPoint;
  final String endPoint;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final List<dynamic>? stops; // List of Map containing name, lat, lng, sequence

  RouteModel({
    required this.id,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.stops,
  });

  factory RouteModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RouteModel(
      id: documentId,
      name: map['name'] ?? '',
      startPoint: map['startPoint'] ?? '',
      endPoint: map['endPoint'] ?? '',
      startLat: map['startLatitude'] != null ? (map['startLatitude'] as num).toDouble() : null,
      startLng: map['startLongitude'] != null ? (map['startLongitude'] as num).toDouble() : null,
      endLat: map['endLatitude'] != null ? (map['endLatitude'] as num).toDouble() : null,
      endLng: map['endLongitude'] != null ? (map['endLongitude'] as num).toDouble() : null,
      stops: map['stopsList'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startPoint': startPoint,
      'endPoint': endPoint,
      if (startLat != null) 'startLatitude': startLat,
      if (startLng != null) 'startLongitude': startLng,
      if (endLat != null) 'endLatitude': endLat,
      if (endLng != null) 'endLongitude': endLng,
      if (stops != null) 'stopsList': stops,
    };
  }

  List<LatLng> getPolylinePoints() {
    final List<LatLng> points = [];
    if (startLat != null && startLng != null) {
      points.add(LatLng(startLat!, startLng!));
    }
    if (stops != null) {
      // Sort stops by sequence if possible, although stopsList is already ordered
      final sortedStops = List.from(stops!)..sort((a, b) {
        final seqA = a['sequence'] ?? 0;
        final seqB = b['sequence'] ?? 0;
        return seqA.compareTo(seqB);
      });

      for (var stop in sortedStops) {
        // Skip sequence 0 and final sequence if they are duplicates of start/end
        final seq = stop['sequence'] ?? 0;
        if (seq == 0 || seq == sortedStops.length - 1) {
          // Some structures put start/end as sequence 0 and N in stopsList,
          // but project-osrm router expects clean sequence. We can just add them all or filter out if they match start/end.
          // Let's just add intermediate ones or add them if they're not duplicates.
        }
        final lat = stop['lat'] != null ? (stop['lat'] as num).toDouble() : null;
        final lng = stop['lng'] != null ? (stop['lng'] as num).toDouble() : null;
        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    if (endLat != null && endLng != null) {
      // Avoid duplicate end point
      final endLatLng = LatLng(endLat!, endLng!);
      if (points.isEmpty || points.last != endLatLng) {
        points.add(endLatLng);
      }
    }
    return points;
  }
}
