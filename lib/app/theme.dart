import 'package:flutter/material.dart';

abstract final class BalanceMateColors {
  static const navy = Color(0xFF061653);
  static const cobalt = Color(0xFF1246D8);
  static const blue = Color(0xFF1379F7);
  static const aqua = Color(0xFF18DFC8);
  static const gold = Color(0xFFFFB524);
  static const ink = Color(0xFF10204C);
}

ThemeData balanceMateTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: BalanceMateColors.cobalt,
    brightness: brightness,
    primary: dark ? const Color(0xFF63D9C7) : BalanceMateColors.cobalt,
    onPrimary: dark ? BalanceMateColors.navy : Colors.white,
    secondary: BalanceMateColors.aqua,
    tertiary: BalanceMateColors.gold,
    surface: dark ? const Color(0xFF101B43) : const Color(0xFFF6F8FF),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF09112D)
        : const Color(0xFFF6F8FF),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF131F48) : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1A2856) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      indicatorColor: BalanceMateColors.aqua.withValues(alpha: .20),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BalanceMateColors.gold,
      foregroundColor: BalanceMateColors.navy,
      shape: StadiumBorder(),
    ),
  );
}
