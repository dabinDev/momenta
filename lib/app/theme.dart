import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Core palette: Deep Space Blue ──
  static const Color primary = Color(0xFF3D8BFF);
  static const Color primaryDeep = Color(0xFF2B76E8);
  static const Color primaryDark = Color(0xFF1E5FC4);
  static const Color amber = Color(0xFF3D8BFF);
  static const Color jade = Color(0xFF3ECFB8);
  static const Color sky = Color(0xFF5B9CFF);
  static const Color coral = Color(0xFF6DD8F0);

  // ── Surfaces: crisp blue-white layering ──
  static const Color canvas = Color(0xFFF2F6FC);
  static const Color canvasWarm = Color(0xFFE8F0FA);
  static const Color surface = Color(0xFFF8FAFD);
  static const Color surfaceSoft = Color(0xFFEDF3FB);
  static const Color surfaceMuted = Color(0xFFE2EBF6);
  static const Color surfaceSky = Color(0xFFEFF4FB);
  static const Color surfaceJade = Color(0xFFE8F8F4);
  static const Color surfaceAmber = Color(0xFFE8F0FA);

  // ── Structure: blue-gray borders & outlines ──
  static const Color outline = Color(0xFFC8D6E6);
  static const Color outlineSoft = Color(0xFFDEE8F4);
  static const Color fieldSurface = Color(0xFFF5F8FC);
  static const Color fieldBorder = Color(0xFFC0D0E4);
  static const Color secondaryButtonSurface = Color(0xFFF0F5FB);

  // ── Text: cool navy spectrum ──
  static const Color text = Color(0xFF162034);
  static const Color muted = Color(0xFF566A82);

  static const LinearGradient warmBackground = LinearGradient(
    colors: <Color>[
      Color(0xFFF5F8FC),
      Color(0xFFE8F0FA),
      Color(0xFFE0EAFA),
      Color(0xFFEFF6FB),
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
        selectionColor: Color(0x303D8BFF),
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
          color: Color(0xFF7888A0),
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
          shadowColor: primaryDeep.withValues(alpha: 0.22),
          disabledBackgroundColor: const Color(0xFFC8D6E6),
          disabledForegroundColor: const Color(0xFF8898AA),
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
          disabledBackgroundColor: const Color(0xFFC8D6E6),
          disabledForegroundColor: const Color(0xFF8898AA),
          overlayColor: primaryDark.withValues(alpha: 0.08),
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
          backgroundColor: const Color(0xFFF5F8FC),
          foregroundColor: primaryDeep,
          side: BorderSide(
            color: const Color(0xFFD0DCEE),
            width: 1,
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
          overlayColor: primary.withValues(alpha: 0.08),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEFF4FB),
        disabledColor: surfaceSoft,
        selectedColor: primary.withValues(alpha: 0.16),
        secondarySelectedColor: primary.withValues(alpha: 0.16),
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
        indicatorColor: primary.withValues(alpha: 0.14),
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
        linearTrackColor: Color(0xFFDAE4F4),
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
