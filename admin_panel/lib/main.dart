import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app/theme/app_theme.dart';
import 'modules/auth/login_screen.dart';
import 'modules/admin/admin_dashboard_screen.dart';
import 'modules/admin/add_edit_bus_screen.dart';
import 'modules/admin/add_edit_driver_screen.dart';
import 'modules/admin/add_edit_route_screen.dart';
import 'modules/admin/add_edit_student_screen.dart';
import 'modules/admin/add_edit_parent_screen.dart';
import 'modules/admin/assign_bus_screen.dart';
import 'modules/admin/manage_buses_screen.dart';
import 'modules/admin/manage_drivers_screen.dart';
import 'modules/admin/manage_parents_screen.dart';
import 'modules/admin/manage_routes_screen.dart';
import 'modules/admin/manage_students_screen.dart';
import 'modules/admin/admin_live_tracking_screen.dart';
import 'modules/admin/reports_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLT Admin Panel',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const AdminDashboardScreen();
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const AdminDashboardScreen(),
        '/add-edit-bus': (_) => const AddEditBusScreen(),
        '/add-edit-driver': (_) => const AddEditDriverScreen(),
        '/add-edit-route': (_) => const AddEditRouteScreen(),
        '/add-edit-student': (_) => const AddEditStudentScreen(),
        '/add-edit-parent': (_) => const AddEditParentScreen(),
        '/manage-buses': (_) => const ManageBusesScreen(),
        '/manage-drivers': (_) => const ManageDriversScreen(),
        '/manage-parents': (_) => const ManageParentsScreen(),
        '/manage-routes': (_) => const ManageRoutesScreen(),
        '/manage-students': (_) => const ManageStudentsScreen(),
        '/assign-bus': (_) => const AssignBusScreen(),
        '/admin-live-tracking': (_) => const AdminLiveTrackingScreen(),
        '/reports': (_) => const ReportsScreen(),
      },
    );
  }
}
