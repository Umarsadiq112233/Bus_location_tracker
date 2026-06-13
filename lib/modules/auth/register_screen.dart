import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:bus_location_tracker/core/utils/snackbar_utils.dart';
import 'package:bus_location_tracker/modules/auth/auth_controller.dart';
import 'package:bus_location_tracker/modules/auth/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/modules/auth/widgets/role_selection_cards.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _role = UserRole.parent;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToPrivacy = false;
  bool _loading = false;        // for Create Account button
  bool _googleLoading = false;  // for Google button
  final AuthService _authService = AuthService();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is UserRole) {
      _role = args;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      SnackbarUtils.showCustomSnackbar(
        context,
        'Please fix the errors in the form before continuing.',
        isError: true,
      );
      return;
    }

    if (!_agreedToPrivacy) {
      SnackbarUtils.showCustomSnackbar(
        context,
        'You must agree to the Privacy Policy to register.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    if (_googleLoading) return; // prevent double tap

    try {
      final user = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _role,
      );

      if (user != null) {
        if (!mounted) return;
        SnackbarUtils.showCustomSnackbar(
          context,
          'Account created successfully!',
          isError: false,
        );

        if (user.role != null) {
          if (!user.isProfileComplete) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.editProfile,
              arguments: {
                'isOnboarding': true,
                'role': user.role,
              },
            );
          } else {
            final authController = const AuthController();
            Navigator.pushReplacementNamed(
              context,
              authController.dashboardFor(user.role!),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return; // prevent double tap
    setState(() => _googleLoading = true);
    try {
      final user = await _authService.signInWithGoogle(defaultRole: _role);
      if (user != null) {
        if (!mounted) return;
        if (!user.isProfileComplete) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.editProfile,
            (route) => false,
            arguments: {
              'isOnboarding': true,
              'role': _role,
            },
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            const AuthController().dashboardFor(_role),
            (route) => false,
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
              title: 'Create Account',
              subtitle: 'Sign up to stay connected with the school bus',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    RoleSelectionCards(
                      selectedRole: _role,
                      onRoleChanged: (role) => setState(() => _role = role),
                    ),
                    const SizedBox(height: 20),
                    AuthField(
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      hint: 'e.g. Sarah Jenkins',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    AuthField(
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      hint: '+1 (555) 000-0000',
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    AuthField(
                      controller: _emailController,
                      icon: Icons.mail_outline_rounded,
                      label: 'Email Address',
                      hint: 'sarah@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
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
                      hint: 'create a strong password',
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
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AuthField(
                      icon: Icons.lock_outline_rounded,
                      label: 'Confirm Password',
                      hint: 'repeat your password',
                      obscure: _obscureConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToPrivacy,
                          onChanged: (val) {
                            setState(() => _agreedToPrivacy = val ?? false);
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: (_loading || _googleLoading) ? null : _register,
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
                                'Create Account',
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
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
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
                          'Already have an account?',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                          child: const Text(
                            'Login',
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
