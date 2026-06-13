import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/app/bus_tracker_app.dart';
import 'package:bus_location_tracker/modules/auth/auth_controller.dart';
import 'package:bus_location_tracker/modules/auth/login_screen.dart';
import 'package:bus_location_tracker/modules/parent/parent_home_screen.dart';
import 'package:bus_location_tracker/modules/splash/welcome_screen.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'parent_test_uid';

  @override
  String? get email => 'parent@test.com';

  @override
  String? get displayName => 'Ahmed Ali';
}

class MockAuthService extends Fake implements AuthService {
  static bool hasUser = false;

  final UserModel _mockParent = UserModel(
    uid: 'parent_test_uid',
    name: 'Ahmed Ali',
    email: 'parent@test.com',
    phone: '12345678',
    role: UserRole.parent,
    childrenUids: ['child1', 'child2'],
    createdAt: DateTime.now(),
  );

  final List<UserModel> _mockChildren = [
    UserModel(
      uid: 'child1',
      name: 'Ali Ahmed',
      email: 'ali@test.com',
      phone: '12345678',
      role: UserRole.student,
      grade: 'Grade 5',
      section: 'A',
      pickupPoint: 'Stop A',
      assignedBusId: 'bus1',
      createdAt: DateTime.now(),
    ),
    UserModel(
      uid: 'child2',
      name: 'Sara Ahmed',
      email: 'sara@test.com',
      phone: '12345678',
      role: UserRole.student,
      grade: 'Grade 3',
      section: 'B',
      pickupPoint: 'Stop B',
      assignedBusId: 'bus1',
      createdAt: DateTime.now(),
    ),
  ];

  final BusModel _mockBus = BusModel(
    id: 'bus1',
    busNumber: '24A',
    plateNumber: 'XYZ-123',
    capacity: 30,
    status: 'active',
    assignedDriverId: 'driver1',
    assignedRouteId: 'route1',
    currentLat: 24.8607,
    currentLng: 67.0011,
  );

  final RouteModel _mockRoute = RouteModel(
    id: 'route1',
    name: 'Route 1',
    startPoint: 'School',
    endPoint: 'Main Gate',
    stops: [
      {'name': 'Stop A', 'sequence': 1},
      {'name': 'Stop B', 'sequence': 2},
    ],
  );

  @override
  User? get currentUser => hasUser ? MockUser() : null;

  @override
  Stream<User?> get authStateChanges => Stream.value(hasUser ? MockUser() : null);

  @override
  Future<UserModel?> getUserData(String uid) async {
    return _mockParent;
  }

  @override
  Future<List<UserModel>> fetchChildren(List<String> uids) async {
    return _mockChildren;
  }

  @override
  Future<BusModel?> fetchAssignedBus(String busId) async {
    return _mockBus;
  }

  @override
  Future<RouteModel?> fetchAssignedRoute(String routeId) async {
    return _mockRoute;
  }

  @override
  Stream<BusModel?> streamBus(String busId) {
    return Stream.value(_mockBus);
  }

  @override
  Future<UserModel?> fetchStudentByEmail(String email) async {
    try {
      return _mockChildren.firstWhere((c) => c.email == email);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> linkChild(String parentUid, String childUid) async {
    return;
  }

  @override
  Future<List<UserModel>> fetchAllStudents() async {
    return _mockChildren;
  }

  @override
  Future<void> unlinkChild(String parentUid, String childUid) async {
    return;
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    AuthService.instance = MockAuthService();
  });

  setUp(() {
    MockAuthService.hasUser = false;
  });

  testWidgets('renders splash then onboarding and role login flow', (
    tester,
  ) async {
    await tester.pumpWidget(const BusTrackerApp());

    expect(find.text('BLT'), findsWidgets);
    expect(find.text('Bus Location Tracker'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Track Your Bus Live'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Login Now'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('renders welcome screen actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('Track every school bus safely.'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  test('maps every role to the correct dashboard route', () {
    const controller = AuthController();

    expect(controller.dashboardFor(UserRole.parent), AppRoutes.parentHome);
    expect(
      controller.dashboardFor(UserRole.student),
      AppRoutes.studentDashboard,
    );
    expect(controller.dashboardFor(UserRole.driver), AppRoutes.driverDashboard);
    expect(controller.dashboardFor(UserRole.admin), AppRoutes.login);
  });

  testWidgets('renders the parent dashboard module', (tester) async {
    MockAuthService.hasUser = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Parent Dashboard'), findsWidgets);
    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Ahmed Ali'), findsOneWidget);
    expect(find.text('2 Children'), findsOneWidget);
  });

  testWidgets('navigates to live tracking from the bottom navigation', (
    tester,
  ) async {
    MockAuthService.hasUser = true;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.location_on_rounded).last);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Bus Details'), findsOneWidget);
    expect(find.text('Bus 24A'), findsOneWidget);
    expect(find.text('Bus Position'), findsWidgets);
  });
}
