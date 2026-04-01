import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFFFF6A1A);
  static const Color primaryDeep = Color(0xFFE65712);
  static const Color amber = Color(0xFFFFB446);
  static const Color jade = Color(0xFF5E9A75);
  static const Color sky = Color(0xFF6D95F4);
  static const Color coral = Color(0xFFF38765);
  static const Color canvas = Color(0xFFFFF8F2);
  static const Color canvasWarm = Color(0xFFFFF0E4);
  static const Color surface = Color(0xFFFFFCFA);
  static const Color surfaceSoft = Color(0xFFFFF4E9);
  static const Color surfaceMuted = Color(0xFFFFEBDD);
  static const Color outline = Color(0xFFF1E2D4);
  static const Color outlineSoft = Color(0xFFF7EEE5);
  static const Color text = Color(0xFF2E2118);
  static const Color muted = Color(0xFF7E6B5C);

  static const LinearGradient warmBackground = LinearGradient(
    colors: <Color>[
      Color(0xFFFFFCF8),
      Color(0xFFFFF4EA),
      Color(0xFFFFF9F4),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: primary,
      secondary: amber,
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
        primaryColor: primary,
        scaffoldBackgroundColor: canvas,
        barBackgroundColor: Colors.transparent,
        textTheme: CupertinoTextThemeData(
          primaryColor: primary,
          textStyle: TextStyle(
            fontSize: 17,
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
        cursorColor: primary,
        selectionColor: Color(0x33FF8B4B),
        selectionHandleColor: primary,
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
        fillColor: Colors.white.withValues(alpha: 0.82),
        hintStyle: const TextStyle(
          fontSize: 17,
          height: 1.45,
          color: Color(0xFFAA998B),
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.18)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD1534A), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD1534A), width: 1.3),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE7D7C9),
          disabledForegroundColor: const Color(0xFFB8A898),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE7D7C9),
          disabledForegroundColor: const Color(0xFFB8A898),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          backgroundColor: Colors.white.withValues(alpha: 0.58),
          foregroundColor: text,
          side: BorderSide.none,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDeep,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.64),
        disabledColor: surfaceSoft,
        selectedColor: primary.withValues(alpha: 0.14),
        secondarySelectedColor: primary.withValues(alpha: 0.14),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFFFE7D3),
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
          fontSize: 17,
          height: 1.52,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
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
