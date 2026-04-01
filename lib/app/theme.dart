import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF2F746A);
  static const Color _secondary = Color(0xFFD79B47);
  static const Color _canvas = Color(0xFFF6EFE4);
  static const Color _surface = Color(0xFFFFFCF7);
  static const Color _surfaceSoft = Color(0xFFF8F2E8);
  static const Color _outline = Color(0xFFE5DAC9);
  static const Color _outlineSoft = Color(0xFFF0E6D8);
  static const Color _text = Color(0xFF22322C);
  static const Color _muted = Color(0xFF69766F);

  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      onPrimary: Colors.white,
      onSecondary: Color(0xFF392507),
      onSurface: _text,
      error: Color(0xFFC76050),
      onError: Colors.white,
      outline: _outline,
      outlineVariant: _outlineSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _canvas,
      canvasColor: _canvas,
      cardColor: _surface,
      shadowColor: const Color(0x16000000),
      splashColor: _primary.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      dividerColor: _outlineSoft,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: _primary,
        selectionColor: Color(0x334D80C9),
        selectionHandleColor: _primary,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: _text,
          letterSpacing: 0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceSoft,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _muted,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
        hintStyle: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Color(0xFF8B968F),
        ),
        prefixIconColor: _muted,
        suffixIconColor: _muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC76050), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC76050), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBBC8C1),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.88),
          textStyle: const TextStyle(
            fontSize: 16,
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
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          foregroundColor: _text,
          side: BorderSide.none,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5EBDD),
        disabledColor: const Color(0xFFEFE5D7),
        selectedColor: const Color(0xFFE3F1EB),
        secondarySelectedColor: const Color(0xFFE3F1EB),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        height: 74,
        indicatorColor: Color(0xFFE3F1EB),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: Color(0xFFE9DFD1),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _text,
        contentTextStyle: const TextStyle(
          fontSize: 15,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.12,
          color: _text,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w700,
          height: 1.18,
          color: _text,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: _text,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: _text,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.48,
          color: _text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: _muted,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
      ),
    );
  }
}
