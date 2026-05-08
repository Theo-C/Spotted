import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================
// Palette « carnet de naturaliste vintage »
// =============================================================

// Surfaces
const surfaceBase = Color(0xFFF5EDDF);
const surfaceCard = Color(0xFFFAF6EC);
const surfaceMuted = Color(0xFFF0E8D2);

// Couleurs primaires
const forestGreen = Color(0xFF1F3D2E);
const forestGreenLight = Color(0xFF2D5A42);
const terracotta = Color(0xFFB8624A);
const gold = Color(0xFFC49120);
const goldLight = Color(0xFFFFD66B);

// Texte
const textPrimary = Color(0xFF2A1F15);
const textSecondary = Color(0xFF6B5D4F);
const textMuted = Color(0xFFA89B86);

// Raretés
const rarityCommon = Color(0xFF7A7569);
const rarityRare = Color(0xFF2D6E8C);
const rarityEpic = Color(0xFF7A3D9A);
const rarityLegendary = Color(0xFFC49120);

// =============================================================
// ThemeData
// =============================================================

ThemeData appTheme() {
  final base = ThemeData.light(useMaterial3: true);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: forestGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: forestGreen,
    onPrimary: surfaceBase,
    secondary: terracotta,
    onSecondary: surfaceBase,
    tertiary: gold,
    surface: surfaceCard,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
  );

  final body = GoogleFonts.karlaTextTheme(base.textTheme).apply(
    bodyColor: textPrimary,
    displayColor: textPrimary,
  );

  TextStyle title({
    required double size,
    FontWeight weight = FontWeight.w500,
    bool italic = false,
    double height = 1.05,
  }) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: height,
        color: textPrimary,
      );

  final textTheme = body.copyWith(
    displayLarge: title(size: 44, italic: true),
    displayMedium: title(size: 34),
    displaySmall: title(size: 28),
    headlineLarge: title(size: 26),
    headlineMedium: title(size: 22),
    headlineSmall: title(size: 18, weight: FontWeight.w600),
    titleLarge: title(size: 18, weight: FontWeight.w600),
    // Micro-texte uppercase (labels) — Karla bold, à utiliser via TextStyle dédiés
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surfaceBase,
    canvasColor: surfaceBase,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceBase,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: title(size: 22),
    ),
    cardTheme: CardThemeData(
      color: surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: textMuted.withValues(alpha: 0.2)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceCard,
      selectedItemColor: forestGreen,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
    ),
    dividerColor: textMuted.withValues(alpha: 0.2),
    iconTheme: const IconThemeData(color: forestGreen),
  );
}
