import 'package:bus_location_tracker/app/routes/app_routes.dart';

import 'package:bus_location_tracker/modules/auth/forgot_password_screen.dart';
import 'package:bus_location_tracker/modules/auth/login_screen.dart';
import 'package:bus_location_tracker/modules/auth/register_screen.dart';
import 'package:bus_location_tracker/modules/auth/role_selection_screen.dart';
import 'package:bus_location_tracker/modules/driver/driver_dashboard_screen.dart';
import 'package:bus_location_tracker/modules/driver/driver_trip_history_screen.dart';
import 'package:bus_location_tracker/modules/driver/emergency_screen.dart';
import 'package:bus_location_tracker/modules/driver/route_stops_screen.dart';
import 'package:bus_location_tracker/modules/driver/start_trip_screen.dart';
import 'package:bus_location_tracker/modules/parent/live_tracking_screen.dart';
import 'package:bus_location_tracker/modules/parent/notifications_screen.dart';
import 'package:bus_location_tracker/modules/parent/parent_children_screen.dart';
import 'package:bus_location_tracker/modules/parent/parent_qr_scanner_screen.dart';
import 'package:bus_location_tracker/modules/parent/child_details_screen.dart';
import 'package:bus_location_tracker/modules/parent/parent_home_screen.dart';
import 'package:bus_location_tracker/modules/parent/trip_history_screen.dart';
import 'package:bus_location_tracker/modules/onboarding/onboarding_screen.dart';
import 'package:bus_location_tracker/modules/profile/edit_profile_screen.dart';
import 'package:bus_location_tracker/modules/profile/notification_settings_screen.dart';
import 'package:bus_location_tracker/modules/profile/app_settings_screen.dart';
import 'package:bus_location_tracker/modules/profile/help_support_screen.dart';
import 'package:bus_location_tracker/modules/profile/profile_screen.dart';
import 'package:bus_location_tracker/modules/splash/splash_screen.dart';
import 'package:bus_location_tracker/modules/splash/welcome_screen.dart';
import 'package:bus_location_tracker/modules/student/student_dashboard_screen.dart';
import 'package:bus_location_tracker/modules/student/student_live_tracking_screen.dart';
import 'package:bus_location_tracker/modules/student/student_notifications_screen.dart';
import 'package:bus_location_tracker/modules/student/student_route_stops_screen.dart';
import 'package:bus_location_tracker/modules/student/student_trip_history_screen.dart';
import 'package:flutter/material.dart';

class AppPages {
  const AppPages._();

  static Map<String, WidgetBuilder> get routes {
    return {
      AppRoutes.splash: (_) => const SplashScreen(),
      AppRoutes.welcome: (_) => const WelcomeScreen(),
      AppRoutes.onboarding: (_) => const OnboardingScreen(),
      AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
      AppRoutes.login: (_) => const LoginScreen(),
      AppRoutes.register: (_) => const RegisterScreen(),
      AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
      AppRoutes.parentHome: (_) => const ParentHomeScreen(),
      AppRoutes.liveTracking: (_) => const LiveTrackingScreen(),
      AppRoutes.tripHistory: (_) => const TripHistoryScreen(),
      AppRoutes.notifications: (_) => const NotificationsScreen(),
      AppRoutes.parentChildren: (_) => const ParentChildrenScreen(),
      AppRoutes.parentQrScanner: (_) => const ParentQrScannerScreen(),
      AppRoutes.childDetails: (_) => const ChildDetailsScreen(),
      AppRoutes.driverDashboard: (_) => const DriverDashboardScreen(),
      AppRoutes.startTrip: (_) => const StartTripScreen(),
      AppRoutes.routeStops: (_) => const RouteStopsScreen(),
      AppRoutes.emergency: (_) => const EmergencyScreen(),
      AppRoutes.driverTripHistory: (_) => const DriverTripHistoryScreen(),

      AppRoutes.studentDashboard: (_) => const StudentDashboardScreen(),
      AppRoutes.studentLiveTracking: (_) => const StudentLiveTrackingScreen(),
      AppRoutes.studentRouteStops: (_) => const StudentRouteStopsScreen(),
      AppRoutes.studentNotifications: (_) => const StudentNotificationsScreen(),
      AppRoutes.studentTripHistory: (_) => const StudentTripHistoryScreen(),
      AppRoutes.profile: (_) => const ProfileScreen(),
      AppRoutes.editProfile: (_) => const EditProfileScreen(),
      AppRoutes.notificationSettings: (_) => const NotificationSettingsScreen(),
      AppRoutes.appSettings: (_) => const AppSettingsScreen(),
      AppRoutes.helpSupport: (_) => const HelpSupportScreen(),
    };
  }
}
