import 'package:bus_location_tracker/modules/student/student_live_tracking_screen.dart';
import 'package:flutter/material.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final busId = args?['busId'] as String?;
    return StudentLiveTrackingScreen(busId: busId);
  }
}
