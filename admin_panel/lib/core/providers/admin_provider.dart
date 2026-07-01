import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../../shared/enums/user_role.dart';

/// Provides the current admin user's data throughout the app.
/// Used to gate UI based on role (ProAdmin vs SchoolAdmin).
class AdminProvider extends ChangeNotifier {
  UserModel? _currentAdmin;

  /// Temporarily stored ProAdmin email for re-auth after creating SchoolAdmin
  String? _proAdminEmail;
  String? _proAdminPassword;

  UserModel? get currentAdmin => _currentAdmin;

  /// Returns true if current user is ProAdmin (or legacy 'admin')
  bool get isProAdmin =>
      _currentAdmin?.role == UserRole.proAdmin ||
      _currentAdmin?.role == UserRole.admin;

  /// Returns true if current user is SchoolAdmin
  bool get isSchoolAdmin => _currentAdmin?.role == UserRole.schoolAdmin;

  /// Returns the schoolId for SchoolAdmin users
  String? get schoolId => _currentAdmin?.schoolId;

  /// Store the current admin user data
  void setAdmin(UserModel? admin) {
    _currentAdmin = admin;
    notifyListeners();
  }

  /// Store ProAdmin credentials temporarily for re-auth after SchoolAdmin creation
  void storeProAdminCredentials(String email, String password) {
    _proAdminEmail = email;
    _proAdminPassword = password;
  }

  String? get proAdminEmail => _proAdminEmail;
  String? get proAdminPassword => _proAdminPassword;

  /// Clear stored credentials (call after re-auth)
  void clearStoredCredentials() {
    _proAdminEmail = null;
    _proAdminPassword = null;
  }

  void clear() {
    _currentAdmin = null;
    _proAdminEmail = null;
    _proAdminPassword = null;
    notifyListeners();
  }
}
