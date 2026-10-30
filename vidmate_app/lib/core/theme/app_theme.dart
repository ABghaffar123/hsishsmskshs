import 'package:flutter/material.dart';

class AppTheme {
  // Dark mode - default
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF171922),
      primary: Color(0xFF6C5CE7),
      secondary: Color(0xFF00CEC9),
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.white,
      onError: Colors.white,
      error: Color(0xFFFF7675),
      surfaceTint: Color(0xFF6C5CE7),
    ),
    scaffoldBackgroundColor: const Color(0xFF0E0F13),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF171922),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF171922),
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: Colors.white70,
        fontSize: 14,
      ),
      bodyMedium: TextStyle(
        color: Colors.white70,
        fontSize: 12,
      ),
    ),
  );

  // Light mode
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      primary: Color(0xFF6C5CE7),
      secondary: Color(0xFF00CEC9),
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
      onError: Colors.white,
      error: Color(0xFFFF7675),
      surfaceTint: Color(0xFF6C5CE7),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: Colors.black87,
        fontSize: 14,
      ),
      bodyMedium: TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
    ),
  );
}