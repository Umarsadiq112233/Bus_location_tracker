import 'app_colors.dart';
import 'app_text_styles.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    return _buildTheme(
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.danger,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get dark {
    return _buildTheme(
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: const Color(0xFF82B7FF),
        secondary: AppColors.secondary,
        error: const Color(0xFFFFB4AB),
        brightness: Brightness.dark,
      ),
    );
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = _textTheme(isDark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F172A)
          : AppColors.surfaceSoft,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? AppColors.textPrimary : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFF263244) : AppColors.outline,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 52),
          textStyle: AppTextStyles.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, 52),
          textStyle: AppTextStyles.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: AppTextStyles.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppTextStyles.label),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2937) : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: AppTextStyles.body.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: AppTextStyles.body.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: AppTextStyles.caption.copyWith(color: scheme.onSurface),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: AppTextStyles.label,
        unselectedLabelStyle: AppTextStyles.label.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final textColor = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final mutedColor = isDark ? const Color(0xFFCBD5E1) : AppColors.textMuted;
    final bodyColor = isDark
        ? const Color(0xFFE2E8F0)
        : AppColors.textSecondary;

    return TextTheme(
      displayLarge: AppTextStyles.display.copyWith(
        fontSize: 32,
        color: textColor,
      ),
      displayMedium: AppTextStyles.display.copyWith(color: textColor),
      headlineSmall: AppTextStyles.headline.copyWith(color: textColor),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: textColor),
      titleMedium: AppTextStyles.title.copyWith(color: textColor),
      titleSmall: AppTextStyles.label.copyWith(color: textColor),
      bodyLarge: AppTextStyles.body.copyWith(fontSize: 16, color: bodyColor),
      bodyMedium: AppTextStyles.body.copyWith(color: bodyColor),
      bodySmall: AppTextStyles.caption.copyWith(color: mutedColor),
      labelLarge: AppTextStyles.label.copyWith(color: textColor),
      labelMedium: AppTextStyles.caption.copyWith(color: mutedColor),
      labelSmall: AppTextStyles.micro.copyWith(color: mutedColor),
    );
  }
}
