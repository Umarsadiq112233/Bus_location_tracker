import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const String fontFamily = 'Roboto';

  static const display = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 28,
    height: 1.12,
    fontWeight: FontWeight.w900,
  );

  static const headline = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w900,
  );

  static const titleLarge = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );

  static const title = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w800,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const bodyStrong = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w800,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w800,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  static const micro = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textMuted,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
}
