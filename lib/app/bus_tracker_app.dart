import 'package:bus_location_tracker/app/bindings/initial_binding.dart';
import 'package:bus_location_tracker/app/routes/app_pages.dart';
import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    InitialBinding.initialize();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BLT - Bus Location Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: AppRoutes.splash,
      routes: AppPages.routes,
    );
  }
}
