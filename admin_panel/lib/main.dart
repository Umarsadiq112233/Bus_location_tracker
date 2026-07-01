import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'app/theme/app_theme.dart';
import 'core/providers/admin_provider.dart';
import 'core/services/auth_service.dart';
import 'core/utils/snackbar_utils.dart';
import 'shared/enums/user_role.dart';
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
import 'modules/admin/manage_schools_screen.dart';
import 'modules/admin/add_edit_school_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminProvider(),
      child: MaterialApp(
        title: 'BLT Admin Panel',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const _AuthGate(),
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
          '/manage-schools': (_) => const ManageSchoolsScreen(),
          '/add-edit-school': (_) => const AddEditSchoolScreen(),
        },
      ),
    );
  }
}

/// Auth gate that loads admin data into the provider before showing dashboard
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return _AdminLoader(uid: snapshot.data!.uid);
        }
        return const LoginScreen();
      },
    );
  }
}

/// Loads admin user data into AdminProvider before showing the dashboard.
/// Handles the case where user refreshes the page (provider data is lost).
class _AdminLoader extends StatefulWidget {
  const _AdminLoader({required this.uid});
  final String uid;

  @override
  State<_AdminLoader> createState() => _AdminLoaderState();
}

class _AdminLoaderState extends State<_AdminLoader> {
  bool _loading = true;
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final provider = context.read<AdminProvider>();

    // If provider already has admin data (e.g. coming from login), skip re-fetch
    if (provider.currentAdmin != null) {
      setState(() => _loading = false);
      return;
    }

    // Fetch from Firestore (e.g. after page refresh)
    final authService = AuthService();
    final userModel = await authService.getUserData(widget.uid);

    if (!mounted) return;

    if (userModel != null &&
        (userModel.role == UserRole.admin ||
            userModel.role == UserRole.proAdmin ||
            userModel.role == UserRole.schoolAdmin)) {
      provider.setAdmin(userModel);
      setState(() => _loading = false);
    } else {
      // Not an admin role — sign out
      await authService.logout();
      if (mounted) {
        provider.clear();
        setState(() {
          _loading = false;
          _accessDenied = true;
        });

        final msg = userModel == null
            ? 'Login failed: Profile not found in Firestore. Please run the create_admin.dart script.'
            : 'Access Denied: Role is "${userModel.role?.name ?? 'unknown'}". Only Admins allowed.';

        SnackbarUtils.showCustomSnackbar(
          context,
          msg,
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accessDenied) {
      return const LoginScreen();
    }
    return const AdminDashboardScreen();
  }
}
