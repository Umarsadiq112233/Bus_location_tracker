import 'dart:math' as math;

import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/services/notification_service.dart';
import 'package:bus_location_tracker/modules/auth/auth_controller.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final startTime = DateTime.now();
    String destinationRoute = AppRoutes.onboarding;

    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        final userModel = await authService.getUserData(user.uid);
        if (userModel != null) {
          if (userModel.role != null) {
            NotificationService().listenToNotifications(userModel.uid);
            destinationRoute = const AuthController().dashboardFor(userModel.role!);
          } else {
            destinationRoute = AppRoutes.roleSelection;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking auth: $e');
    }

    final elapsed = DateTime.now().difference(startTime);
    final remainingDelay = const Duration(milliseconds: 2100) - elapsed;
    if (remainingDelay > Duration.zero) {
      await Future<void>.delayed(remainingDelay);
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, destinationRoute);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SplashPainter(
              colorScheme: scheme,
              progress: _controller.value,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedLogo(progress: _controller.value),
                  const SizedBox(height: 24),
                  Text(
                    'BLT',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bus Location Tracker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 150,
                    child: LinearProgressIndicator(
                      value: .25 + (_controller.value * .7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lift = math.sin(progress * math.pi * 2) * 5;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 112 + (progress * 16),
          height: 112 + (progress * 16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: .08),
          ),
        ),
        Transform.translate(
          offset: Offset(0, lift),
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .28),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              Icons.directions_bus_filled_rounded,
              color: scheme.onPrimary,
              size: 44,
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashPainter extends CustomPainter {
  const _SplashPainter({required this.colorScheme, required this.progress});

  final ColorScheme colorScheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colorScheme.surface);

    final route = Paint()
      ..color = colorScheme.primary.withValues(alpha: .14)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * -.1, size.height * .72)
      ..cubicTo(
        size.width * .22,
        size.height * .48,
        size.width * .42,
        size.height * .84,
        size.width * .66,
        size.height * .56,
      )
      ..cubicTo(
        size.width * .82,
        size.height * .38,
        size.width * .92,
        size.height * .44,
        size.width * 1.1,
        size.height * .28,
      );
    canvas.drawPath(path, route);

    final dot = Paint()..color = colorScheme.tertiary;
    final x = size.width * (.18 + progress * .64);
    final y = size.height * (.66 - math.sin(progress * math.pi) * .18);
    canvas.drawCircle(Offset(x, y), 7, dot);
  }

  @override
  bool shouldRepaint(covariant _SplashPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colorScheme != colorScheme;
  }
}
