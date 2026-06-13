import 'package:bus_location_tracker/core/widgets/app_screen.dart';
import 'package:bus_location_tracker/core/widgets/flow_widgets.dart';
import 'package:flutter/material.dart';

class DriverTripHistoryScreen extends StatelessWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScreen(
      title: 'Driver Trip History',
      subtitle: 'Completed trips with timings, stops, and status.',
      children: [
        InfoCard(
          icon: Icons.history_rounded,
          title: 'Today - BLT-24',
          subtitle: 'North Campus Loop - 06:40 to 07:33 - 8 stops completed',
          trailing: 'Done',
        ),
        InfoCard(
          icon: Icons.history_rounded,
          title: 'Yesterday - BLT-24',
          subtitle: 'Gulshan Express - 13:15 to 14:20 - 10 stops completed',
          trailing: 'Done',
        ),
      ],
    );
  }
}
