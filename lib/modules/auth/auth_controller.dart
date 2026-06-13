import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';

class AuthController {
  const AuthController();

  String dashboardFor(UserRole role) {
    return switch (role) {
      UserRole.parent => AppRoutes.parentHome,
      UserRole.student => AppRoutes.studentDashboard,
      UserRole.driver => AppRoutes.driverDashboard,
      UserRole.admin => AppRoutes.login,
    };
  }
}
