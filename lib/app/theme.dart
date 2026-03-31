import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF2F6E7C);
  static const Color _accent = Color(0xFFE28A45);
  static const Color _canvas = Color(0xFFF7F4EE);
  static const Color _panel = Color(0xFFFFFCF7);
  static const Color _line = Color(0xFFE4DDD3);
  static const Color _text = Color(0xFF223038);
  static const Color _subtleText = Color(0xFF617079);

  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: _primary,
      secondary: _accent,
      surface: _panel,
      onPrimary: Colors.white,
      onSecondary: Color(0xFF2D1B0E),
      onSurface: _text,
      error: Color(0xFFB74134),
      onError: Colors.white,
      outline: _line,
      outlineVariant: Color(0xFFEAE1D4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _canvas,
      splashColor: _primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      dividerColor: _line,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _text,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _text,
          letterSpacing: 0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _subtleText,
        ),
        hintStyle: const TextStyle(
          fontSize: 17,
          height: 1.4,
          color: Color(0xFF8A948F),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(58),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBCC9C4),
          disabledForegroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(58),
          backgroundColor: Colors.white,
          foregroundColor: _text,
          side: const BorderSide(color: _line),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0E7D8),
        disabledColor: const Color(0xFFE7DFD2),
        selectedColor: const Color(0xFFDCECF0),
        secondarySelectedColor: const Color(0xFFDCECF0),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        labelStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: Color(0xFFDCECF0),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: Color(0xFFE5DDD1),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: _text,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: _text,
        ),
        titleLarge: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: _text,
        ),
        titleMedium: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: _text,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 1.5,
          color: _text,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: _subtleText,
        ),
        labelLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
      ),
    );
  }
}
