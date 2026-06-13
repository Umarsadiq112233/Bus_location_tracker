import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/core/widgets/custom_button.dart';
import 'package:bus_location_tracker/modules/auth/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Track every school bus safely.',
      subtitle: 'Live routes, alerts, and role-based dashboards in one app.',
      badge: 'Welcome to BLT',
      showBackButton: false,
      showVisual: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WelcomeLogo(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: 'Login',
              icon: Icons.login_rounded,
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: 'Create Account',
              icon: Icons.person_add_rounded,
              isOutlined: true,
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.roleSelection);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeLogo extends StatelessWidget {
  const _WelcomeLogo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .24),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_bus_filled_rounded,
            color: scheme.onPrimary,
            size: 32,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BLT',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              Text('Bus Location Tracker'),
            ],
          ),
        ),
      ],
    );
  }
}
