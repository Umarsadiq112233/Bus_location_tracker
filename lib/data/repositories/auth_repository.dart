import 'package:bus_location_tracker/core/services/auth_service.dart';

class AuthRepository {
  const AuthRepository(this._service);

  final AuthService _service;

  Future<void> signIn(String email, String password) {
    return _service.loginWithEmailAndPassword(email, password);
  }
}
