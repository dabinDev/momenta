import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFFF06E42);
  static const Color primaryDeep = Color(0xFFD95C35);
  static const Color primaryDark = Color(0xFFB84A2C);
  static const Color amber = Color(0xFFF4B651);
  static const Color jade = Color(0xFF58A87E);
  static const Color sky = Color(0xFF5D8DF7);
  static const Color coral = Color(0xFFF09473);
  static const Color canvas = Color(0xFFFFF9F4);
  static const Color canvasWarm = Color(0xFFFFF1E6);
  static const Color surface = Color(0xFFFFFCFA);
  static const Color surfaceSoft = Color(0xFFFFF5EC);
  static const Color surfaceMuted = Color(0xFFF8EEE6);
  static const Color outline = Color(0xFFEEDFD3);
  static const Color outlineSoft = Color(0xFFF6EEE8);
  static const Color fieldSurface = Color(0xFFFFFCF8);
  static const Color fieldBorder = Color(0xFFE7D9D1);
  static const Color secondaryButtonSurface = Color(0xFFF6FAFF);
  static const Color text = Color(0xFF302219);
  static const Color muted = Color(0xFF7F6A5A);

  static const LinearGradient warmBackground = LinearGradient(
    colors: <Color>[
      Color(0xFFFFFCF8),
      Color(0xFFFFF3E9),
      Color(0xFFF4F8FF),
      Color(0xFFF2FAF6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: primaryDeep,
      secondary: sky,
      tertiary: jade,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: text,
      onSurface: text,
      error: Color(0xFFD1534A),
      onError: Colors.white,
      outline: outline,
      outlineVariant: outlineSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      shadowColor: Colors.transparent,
      dividerColor: outline,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        primaryColor: primaryDeep,
        scaffoldBackgroundColor: canvas,
        barBackgroundColor: Colors.transparent,
        textTheme: CupertinoTextThemeData(
          primaryColor: primaryDeep,
          textStyle: TextStyle(
            fontSize: 18,
            height: 1.45,
            color: text,
          ),
          navTitleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryDeep,
        selectionColor: Color(0x33F08B62),
        selectionHandleColor: primaryDeep,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 54,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldSurface,
        hintStyle: const TextStyle(
          fontSize: 17,
          height: 1.45,
          color: Color(0xFF917F72),
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: primaryDeep,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: fieldBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: fieldBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryDeep,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD1534A),
            width: 1.1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD1534A),
            width: 1.4,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          backgroundColor: primaryDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD8C5B6),
          disabledForegroundColor: const Color(0xFF8F7E71),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          backgroundColor: primaryDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD8C5B6),
          disabledForegroundColor: const Color(0xFF8F7E71),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: secondaryButtonSurface,
          foregroundColor: primaryDeep,
          side: BorderSide(
            color: primaryDeep.withValues(alpha: 0.12),
            width: 0.8,
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFF8F3),
        disabledColor: surfaceSoft,
        selectedColor: primary.withValues(alpha: 0.18),
        secondarySelectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide(
          color: primaryDeep.withValues(alpha: 0.12),
          width: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.16),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDeep,
        linearTrackColor: Color(0xFFDDE6FF),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: const TextStyle(
          fontSize: 15,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        minVerticalPadding: 10,
        iconColor: muted,
        textColor: text,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.12,
          color: text,
          letterSpacing: -0.6,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.16,
          color: text,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.22,
          color: text,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.28,
          color: text,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 1.52,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.48,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
