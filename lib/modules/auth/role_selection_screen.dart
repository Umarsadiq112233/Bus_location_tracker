import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/utils/snackbar_utils.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// Professional Role Selection Screen
// ══════════════════════════════════════════════════════════════

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  UserRole? _selectedRole;
  bool _loading = false;
  late final AnimationController _headerCtrl;
  late final AnimationController _cardsCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  static const _roles = [
    _RoleInfo(
      role: UserRole.parent,
      title: 'Parent',
      subtitle: 'Track your child\'s bus live and get arrival alerts',
      icon: Icons.family_restroom_rounded,
      gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
      bg: Color(0xFFE3F2FD),
    ),
    _RoleInfo(
      role: UserRole.student,
      title: 'Student',
      subtitle: 'View your bus route, stops and live ETA',
      icon: Icons.school_rounded,
      gradient: [Color(0xFF0A6FE8), Color(0xFF42A5F5)],
      bg: Color(0xFFE5F0FF),
    ),
    _RoleInfo(
      role: UserRole.driver,
      title: 'Driver',
      subtitle: 'Manage trips, share live location & handle emergencies',
      icon: Icons.directions_bus_filled_rounded,
      gradient: [Color(0xFF1B7F45), Color(0xFF27A35C)],
      bg: Color(0xFFEAF8EF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_selectedRole == null || _loading) return;

    final authService = AuthService();
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      // User is already logged in (e.g. Google Auth user with no role).
      // Update role in Firestore and redirect directly to dashboard.
      setState(() => _loading = true);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'role': _selectedRole!.name,
        });

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.editProfile,
          (route) => false,
          arguments: {
            'isOnboarding': true,
            'role': _selectedRole,
          },
        );
      } catch (e) {
        if (!mounted) return;
        SnackbarUtils.showCustomSnackbar(
          context,
          'Failed to save role: ${e.toString()}',
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // Guest registering
      Navigator.pushNamed(
        context,
        AppRoutes.register,
        arguments: _selectedRole,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A6FE8), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_bus_filled_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Who are you?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select your role to get started with BLT',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Role Cards ───────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _roles.length,
                itemBuilder: (context, index) {
                  final info = _roles[index];
                  final delay = index * 0.15;
                  return AnimatedBuilder(
                    animation: _cardsCtrl,
                    builder: (context, child) {
                      final t = Curves.easeOutBack.transform(
                        (((_cardsCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0)),
                      );
                      return Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 40 * (1 - t)),
                          child: child,
                        ),
                      );
                    },
                    child: _RoleCard(
                      info: info,
                      isSelected: _selectedRole == info.role,
                      onTap: () => setState(() => _selectedRole = info.role),
                    ),
                  );
                },
              ),
            ),

            // ── Continue Button ──────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: AnimatedOpacity(
                opacity: _selectedRole != null ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: (_selectedRole != null && !_loading) ? _proceed : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _loading
                          ? [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ]
                          : [
                              Text(
                                _selectedRole != null
                                    ? 'Continue as ${_selectedRole!.name[0].toUpperCase()}${_selectedRole!.name.substring(1)}'
                                    : 'Select a role to continue',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (_selectedRole != null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Already have account ─────────────────────────────
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.login),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role Card Widget ─────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  final _RoleInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? info.bg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? info.gradient.first : const Color(0xFFE5E7EB),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: info.gradient.first.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container with gradient
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: info.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  info.icon,
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? info.gradient.first
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? info.gradient.first.withValues(alpha: 0.75)
                            : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Check indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? LinearGradient(colors: info.gradient)
                      : null,
                  color: isSelected ? null : const Color(0xFFE5E7EB),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data Class ───────────────────────────────────────────────────────────────

class _RoleInfo {
  const _RoleInfo({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.bg,
  });

  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color bg;
}
