import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/modules/auth/auth_controller.dart';
import 'package:bus_location_tracker/core/utils/snackbar_utils.dart';
import 'package:bus_location_tracker/modules/auth/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _controller = const AuthController();
  final _formKey = GlobalKey<FormState>();

  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;       // for Login button
  bool _googleLoading = false; // for Google button

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      SnackbarUtils.showCustomSnackbar(
        context,
        'Please fix the errors in the form before continuing.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final userModel = await _authService.loginWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userModel != null) {
        if (!mounted) return;
        if (userModel.role == UserRole.admin) {
          await _authService.logout();
          if (!mounted) return;
          SnackbarUtils.showCustomSnackbar(
            context,
            'Access Denied: Admin accounts are not allowed to log in to the mobile application.',
            isError: true,
          );
        } else if (userModel.role != null) {
          if (!userModel.isProfileComplete) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.editProfile,
              arguments: {
                'isOnboarding': true,
                'role': userModel.role,
              },
            );
          } else {
            NotificationService().listenToNotifications(userModel.uid);
            Navigator.pushReplacementNamed(
              context,
              _controller.dashboardFor(userModel.role!),
            );
          }
        } else {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.roleSelection,
          );
        }
      } else {
        if (!mounted) return;
        SnackbarUtils.showCustomSnackbar(
          context,
          'Login failed. User not found.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _googleLoading = true);
    try {
      final userModel = await _authService.signInWithGoogle();
      if (userModel != null) {
        if (!mounted) return;
        if (userModel.role == UserRole.admin) {
          await _authService.logout();
          if (!mounted) return;
          SnackbarUtils.showCustomSnackbar(
            context,
            'Access Denied: Admin accounts are not allowed to log in to the mobile application.',
            isError: true,
          );
        } else if (userModel.role != null) {
          if (!userModel.isProfileComplete) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.editProfile,
              arguments: {
                'isOnboarding': true,
                'role': userModel.role,
              },
            );
          } else {
            NotificationService().listenToNotifications(userModel.uid);
            Navigator.pushReplacementNamed(
              context,
              _controller.dashboardFor(userModel.role!),
            );
          }
        } else {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.roleSelection,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(
              title: 'Welcome Back',
              subtitle: 'Log in to track the school bus live',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthField(
                      controller: _emailController,
                      icon: Icons.mail_outline_rounded,
                      label: 'Email Address',
                      hint: 'enter your email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AuthField(
                      controller: _passwordController,
                      icon: Icons.lock_outline_rounded,
                      label: 'Password',
                      hint: 'enter your password',
                      obscure: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.forgotPassword,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Login Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: (_loading || _googleLoading) ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: _googleLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GoogleLogoIcon(size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Don\'t have an account?',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.register,
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
