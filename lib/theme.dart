import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const navy = Color(0xFF102A43);
  static const deepNavy = Color(0xFF051434);
  static const blue = Color(0xFF2563EB);
  static const buttonBlue = Color(0xFF1057E8);
  static const gold = Color(0xFFFBBF24);
  static const background = Color(0xFFF6F8FC);
  static const authBackground = Color(0xFFF5F7FB);
  static const text = Color(0xFF102A43);
  static const heading = Color(0xFF082044);
  static const muted = Color(0xFF64748B);
  static const slate = Color(0xFF475569);
  static const lightBlue = Color(0xFFEFF6FF);
  static const paleBlue = Color(0xFFDBEAFE);
  static const border = Color(0xFFE6ECF3);
  static const inputBorder = Color(0xFFDDE6F0);
  static const inputFill = Color(0xFFF8FAFC);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF059669);
}

class AppRadii {
  const AppRadii._();

  static const card = 18.0;
  static const panel = 22.0;
  static const hero = 24.0;
  static const input = 14.0;
  static const pill = 999.0;
}

class AppShadows {
  const AppShadows._();

  static const panel = [
    BoxShadow(
      color: Color(0x14102A43),
      offset: Offset(0, 8),
      blurRadius: 18,
    ),
  ];

  static const soft = [
    BoxShadow(
      color: Color(0x0D102A43),
      offset: Offset(0, 5),
      blurRadius: 14,
    ),
  ];
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.gold,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.input)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      labelStyle: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.text,
        fontSize: 42,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: AppColors.text,
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: AppColors.slate,
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
      ),
    ),
  );
}
