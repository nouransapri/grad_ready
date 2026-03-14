import 'package:flutter/material.dart';

/// App-wide theme and colors used by standard pages (home, login, job requirements).
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2A6CFF);
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color secondary = Color(0xFF9226FF);
  static const Color scaffoldBackground = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: Colors.red.shade700,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: scaffoldBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF424242)),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF757575)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
  );
}
