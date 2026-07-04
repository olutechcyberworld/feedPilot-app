// lib/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// FeedPilot application theme — MATERIAL_3 dark mode.
/// Single source of all color, typography, and component styling.
/// Import this file wherever ThemeData or a color constant is needed.
class AppTheme {
  AppTheme._();

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenLight = Color(0xFF66BB6A);
  static const Color primaryGreenDark = Color(0xFF1B5E20);

  // ── Dark surface palette ───────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color surfaceVariant = Color(0xFF21262D);
  static const Color outlineColor = Color(0xFF30363D);

  // ── Text palette ───────────────────────────────────────────────────────────
  static const Color onSurfacePrimary = Color(0xFFE6EDF3);
  static const Color onSurfaceSecondary = Color(0xFF8B949E);
  static const Color onSurfaceTertiary = Color(0xFF6E7681);

  // ── Semantic status palette ────────────────────────────────────────────────
  // Used by ConnectivityBadge and sensor status indicators.
  static const Color statusOnline = Color(0xFF3FB950); // Tier 3 — cloud
  static const Color statusLocal = Color(0xFFD29922); // Tier 2 — local REST
  static const Color statusAuto = Color(0xFF58A6FF); // Tier 1 — autonomous
  static const Color statusOffline =
      Color(0xFFF85149); // Tier 0 — device offline
  static const Color statusWarning = Color(0xFFFFC107);
  static const Color statusDanger = Color(0xFFF44336);

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surfaceDark,
      onSurface: onSurfacePrimary,
      surfaceContainerHighest: surfaceVariant,
      outline: outlineColor,
      error: statusDanger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: onSurfacePrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: surfaceDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: onSurfacePrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(color: onSurfaceSecondary, size: 22),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── NavigationBar (M3) ─────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryGreen.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryGreenLight, size: 22);
          }
          return const IconThemeData(color: onSurfaceSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryGreenLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: onSurfaceSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
        elevation: 0,
        height: 64,
      ),

      // ── Input decoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: statusDanger),
        ),
        labelStyle: const TextStyle(color: onSurfaceSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: onSurfaceTertiary, fontSize: 14),
        counterStyle: const TextStyle(color: onSurfaceTertiary, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── ListTile ───────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: onSurfacePrimary,
        iconColor: onSurfaceSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),

      // ── Icons ──────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: onSurfaceSecondary,
        size: 20,
      ),

      // ── Typography ─────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w700),
        displayMedium:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w700),
        displaySmall:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w600),
        headlineLarge:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w600),
        headlineSmall:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w500),
        titleSmall:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: onSurfacePrimary),
        bodyMedium: TextStyle(color: onSurfacePrimary),
        bodySmall: TextStyle(color: onSurfaceSecondary),
        labelLarge:
            TextStyle(color: onSurfacePrimary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: onSurfaceSecondary, fontSize: 11),
        labelSmall: TextStyle(color: onSurfaceTertiary, fontSize: 10),
      ),

      // ── FilledButton ───────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreenLight,
          side: const BorderSide(color: primaryGreen),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ── SnackBar ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: onSurfacePrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
