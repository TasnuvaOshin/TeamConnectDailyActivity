import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ACI Forest palette — mirrors the web design tokens (§0.1 of the
/// replication guide). Hex values are the documented OKLCH approximations.
class AppColors {
  static const bg = Color(0xFFF5F8F3); // --background
  static const text = Color(0xFF0F2A1E); // --foreground
  static const forestDeep = Color(0xFF173A2A); // --forest-deep
  static const forest = Color(0xFF22563E); // --forest
  static const forestSoft = Color(0xFF4C8863); // --forest-soft
  static const moss = Color(0xFF5D9E75); // --moss
  static const lime = Color(0xFFA6E663); // --lime
  static const amber = Color(0xFFD8A24A); // --amber-accent
  static const card = Colors.white; // --card
  static const muted = Color(0xFFF1F5EE); // --muted
  static const mute = Color(0xFF617369); // --muted-foreground
  static const border = Color(0xFFE1E7DD); // --border
  static const destructive = Color(0xFFD64228); // --destructive
  static const sidebar = forestDeep; // --sidebar
  static const sidebarAccent = Color(0xFF204C36); // --sidebar-accent

  // Task priority / status pill palette (§4.3)
  static const slate = Color(0xFF64748B);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);
}

/// Display font (Manrope 600–800) for headings and headline stats.
TextStyle display({
  double size = 20,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.text,
  double? height,
}) =>
    GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.2,
      height: height,
    );

/// System mono — timestamps, IDs, demo emails.
TextStyle mono({
  double size = 12,
  Color color = AppColors.text,
  FontWeight weight = FontWeight.w500,
}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.forestDeep,
      secondary: AppColors.moss,
      surface: AppColors.card,
      onPrimary: Colors.white,
      onSurface: AppColors.text,
      error: AppColors.destructive,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.forestDeep,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // cards default rounded-2xl
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF9EAEA4), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forestDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forestDeep,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.forestDeep,
      unselectedLabelColor: AppColors.mute,
      indicatorColor: AppColors.forest,
    ),
    dividerColor: AppColors.border,
  );
}
