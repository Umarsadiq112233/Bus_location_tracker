import 'package:flutter/material.dart';

enum AppRole { student, parent, driver, admin }

class RolePalette {
  const RolePalette({
    required this.primary,
    required this.secondary,
    required this.container,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final Color primary;
  final Color secondary;
  final Color container;
  final Color gradientStart;
  final Color gradientEnd;
}

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF0A6FE8);
  static const primaryDark = Color(0xFF0D47A1);
  static const primaryLight = Color(0xFFE5F0FF);

  static const secondary = Color(0xFFFFB703);
  static const warning = Color(0xFFEF7B45);
  static const danger = Color(0xFFD64B4B);
  static const success = Color(0xFF27A35C);
  static const info = Color(0xFF00838F);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF6F8FA);
  static const surfaceTint = Color(0xFFEAF5F3);
  static const outline = Color(0xFFE5E7EB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted = Color(0xFF667085);

  static const student = RolePalette(
    primary: Color(0xFF0A6FE8),
    secondary: Color(0xFFFFB703),
    container: Color(0xFFE5F0FF),
    gradientStart: Color(0xFF0A6FE8),
    gradientEnd: Color(0xFF42A5F5),
  );

  static const parent = RolePalette(
    primary: Color(0xFF1565C0),
    secondary: Color(0xFF27A35C),
    container: Color(0xFFE3F2FD),
    gradientStart: Color(0xFF1565C0),
    gradientEnd: Color(0xFF42A5F5),
  );

  static const driver = RolePalette(
    primary: Color(0xFF0A6FE8),
    secondary: Color(0xFFFFB703),
    container: Color(0xFFE5F0FF),
    gradientStart: Color(0xFF0D47A1),
    gradientEnd: Color(0xFF0A6FE8),
  );

  static const admin = RolePalette(
    primary: Color(0xFF673AB7),
    secondary: Color(0xFF0A6FE8),
    container: Color(0xFFF0E9FF),
    gradientStart: Color(0xFF512DA8),
    gradientEnd: Color(0xFF673AB7),
  );

  static RolePalette role(AppRole role) {
    return switch (role) {
      AppRole.student => student,
      AppRole.parent => parent,
      AppRole.driver => driver,
      AppRole.admin => admin,
    };
  }
}
