import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0F0A);
  static const surface = Color(0xFF111811);
  static const card = Color(0xFF1A231A);
  static const primary = Color(0xFF00C853);
  static const primaryDark = Color(0xFF009624);
  static const accent = Color(0xFF00E5FF);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFFF5252);
  static const textPrimary = Color(0xFFE8F5E9);
  static const textSecondary = Color(0xFF81C784);
  static const divider = Color(0xFF2E3E2E);
  static const gridLine = Color(0xFF1E2E1E);
  static const crosshair = Color(0xFF00E5FF);
  static const trackLine = Color(0xFF00C853);
  static const pinColor = Color(0xFFFF5252);
  static const radiusLine = Color(0xFF00C853);
  static const radiusFill = Color(0x1100C853);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerColor: AppColors.divider,
    useMaterial3: true,
  );
}
