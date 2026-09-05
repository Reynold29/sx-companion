import 'package:flutter/material.dart';

ThemeData buildSxTheme() {
  const gold = Color(0xFFE0B84A);
  const navy = Color(0xFF0E141C);
  final scheme = ColorScheme.fromSeed(
    seedColor: gold,
    brightness: Brightness.dark,
    surface: const Color(0xFF151C26),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: gold,
      surface: const Color(0xFF151C26),
    ),
    scaffoldBackgroundColor: navy,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1C2533),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF121820),
      indicatorColor: gold.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
  );
}
