import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF000000); // Changed from Purple to Black
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color accentColorGold = Color(0xFFFFD700);
  
  // Light Theme Colors
  static const Color lightPrimary = Color(0xFF000000); // Changed from Navy to Black
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Colors.white;
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000); // True Black
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkCard = Color(0xFF1A1A1A);

  static TextTheme textTheme(bool isDark) {
    final baseColor = isDark ? Colors.white : Colors.black87;
    return GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: baseColor),
      headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: baseColor),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: baseColor),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: baseColor.withOpacity(0.9)),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: baseColor.withOpacity(0.8)),
    );
  }

  static ThemeData get lightTheme {
    final baseText = textTheme(false);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightPrimary,
        primary: lightPrimary,
        secondary: secondaryColor,
        surface: lightSurface,
        onSurface: Colors.black87,
      ),
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        color: lightSurface,
      ),
      inputDecorationTheme: _inputTheme(lightPrimary, false),
      elevatedButtonTheme: _buttonTheme(lightPrimary, false),
    );
  }

  static ThemeData get darkTheme {
    final baseText = textTheme(true);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accentColorGold,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: accentColorGold,
        primary: accentColorGold,
        secondary: const Color(0xFF003366), // Navy Blue
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: baseText.titleLarge?.copyWith(fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        color: darkCard,
      ),
      inputDecorationTheme: _inputTheme(accentColorGold, true),
      elevatedButtonTheme: _buttonTheme(accentColorGold, true),
    );
  }

  static InputDecorationTheme _inputTheme(Color primary, bool isDark) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? darkSurface : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  static ElevatedButtonThemeData _buttonTheme(Color primary, bool isDark) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
