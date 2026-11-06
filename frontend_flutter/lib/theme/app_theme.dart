import 'package:flutter/material.dart';

class AppTheme {
  // Colores Oficiales StarMaker Lite
  static const Color primaryRed = Color(0xFFE51937);
  static const Color primaryRedLight = Color(0xFFFF4D73);
  static const Color primaryCrimson = Color(0xFFE51937);
  static const Color secondaryGold = Color(0xFFFFB800);
  static const Color accentPurple = Color(0xFF6B46C1);
  static const Color backgroundLight = Color(0xFFF7F8FC);
  static const Color backgroundDark = Color(0xFF140824);
  static const Color backgroundCard = Colors.white;
  static const Color cardWhite = Colors.white;
  static const Color cardBorder = Color(0xFFEEF0F6);
  static const Color textDark = Color(0xFF1E1E28);
  static const Color textGrey = Color(0xFF8E8E9B);
  static const Color textMuted = Color(0xFF8E8E9B);
  static const Color textLight = Colors.white;
  static const Color borderLight = Color(0xFFEEF0F6);

  // Colores Pastel Oficiales de Tarjetas StarMaker
  static const Color pastelLavender = Color(0xFFF0ECFC);
  static const Color pastelPeach = Color(0xFFFFF0E5);
  static const Color pastelMint = Color(0xFFE8F7F0);
  static const Color pastelPink = Color(0xFFFFE8EF);
  static const Color pastelYellow = Color(0xFFFFF8E1);
  static const Color pastelCyan = Color(0xFFE3F7FC);

  // Degradados Oficiales
  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFE51937), Color(0xFFFF5277)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE51937), Color(0xFFFF5277)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF7F8FC), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryRed,
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: secondaryGold,
        surface: cardWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
      ),
      cardTheme: CardTheme(
        color: cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 0.8),
        ),
      ),
      useMaterial3: true,
    );
  }
}
