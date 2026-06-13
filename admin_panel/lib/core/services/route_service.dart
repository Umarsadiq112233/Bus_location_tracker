import 'package:cloud_firestore/cloud_firestore.dart';

class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveRoute({
    required String name,
    required String startName,
    required double startLat,
    required double startLng,
    required String endName,
    required double endLat,
    required double endLng,
    required List<Map<String, dynamic>> stops, // list of stops {name, lat, lng, sequence}
    required String status,
  }) async {
    final batch = _firestore.batch();

    // 1. Create a new route document
    final routeRef = _firestore.collection('routes').doc();
    final routeId = routeRef.id;

    batch.set(routeRef, {
      'name': name,
      'startPoint': startName,
      'startLatitude': startLat,
      'startLongitude': startLng,
      'endPoint': endName,
      'endLatitude': endLat,
      'endLongitude': endLng,
      'status': status,
      'stopsCount': stops.length + 2, // including start and end
      'createdAt': Timestamp.now(),
      // Store stops list inside route document for simple map rendering
      'stopsList': [
        {'name': startName, 'lat': startLat, 'lng': startLng, 'sequence': 0},
        for (var i = 0; i < stops.length; i++)
          {
            'name': stops[i]['name'],
            'lat': stops[i]['lat'],
            'lng': stops[i]['lng'],
            'sequence': i + 1,
          },
        {'name': endName, 'lat': endLat, 'lng': endLng, 'sequence': stops.length + 1},
      ],
    });

    // 2. Write to routeStops collection for separate lookups
    // Start stop
    final startStopRef = _firestore.collection('routeStops').doc('${routeId}_start');
    batch.set(startStopRef, {
      'routeId': routeId,
      'stopName': startName,
      'latitude': startLat,
      'longitude': startLng,
      'sequence': 0,
      'status': 'active',
    });

    // Intermediate stops
    for (var i = 0; i < stops.length; i++) {
      final stopRef = _firestore.collection('routeStops').doc('${routeId}_stop_$i');
      batch.set(stopRef, {
        'routeId': routeId,
        'stopName': stops[i]['name'],
        'latitude': stops[i]['lat'],
        'longitude': stops[i]['lng'],
        'sequence': i + 1,
        'status': 'active',
      });
    }

    // End stop
    final endStopRef = _firestore.collection('routeStops').doc('${routeId}_end');
    batch.set(endStopRef, {
      'routeId': routeId,
      'stopName': endName,
      'latitude': endLat,
      'longitude': endLng,
      'sequence': stops.length + 1,
      'status': 'active',
    });

    await batch.commit();
  }
}
