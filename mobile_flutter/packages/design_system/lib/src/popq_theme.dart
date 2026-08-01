import 'package:flutter/material.dart';

abstract final class PopqPalette {
  // 공통 브랜드 색상
  static const ink = Color(0xFF17231F);
  static const forest = Color(0xFF174D3B);
  static const coral = Color(0xFFFF6B52);
  static const lime = Color(0xFFC7FF00);
  static const purple = Color(0xFF8B5CF6);

  // 기본 모드
  static const cream = Color(0xFFFFF8EB);
  static const mist = Color(0xFFF1F5F2);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE0E5E1);
  static const lightMutedText = Color(0xFF65716B);

  // 다크 모드
  static const night = Color(0xFF050A10);
  static const nightSurface = Color(0xFF0B131B);
  static const nightCard = Color(0xFF111C25);
  static const nightElevated = Color(0xFF17232D);
  static const nightBorder = Color(0xFF24303B);
  static const nightText = Color(0xFFF4F7FA);
  static const nightMutedText = Color(0xFF98A5B3);
}

abstract final class PopqSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class PopqTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PopqPalette.forest,
      brightness: Brightness.light,
    ).copyWith(
      primary: PopqPalette.forest,
      onPrimary: Colors.white,
      secondary: PopqPalette.purple,
      onSecondary: Colors.white,
      tertiary: PopqPalette.coral,
      onTertiary: PopqPalette.ink,
      surface: PopqPalette.cream,
      onSurface: PopqPalette.ink,
      outline: PopqPalette.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PopqPalette.cream,

      appBarTheme: const AppBarTheme(
        backgroundColor: PopqPalette.cream,
        foregroundColor: PopqPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: PopqPalette.lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: PopqPalette.lightBorder,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PopqPalette.lime.withValues(alpha: 0.42),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected
                ? PopqPalette.forest
                : PopqPalette.lightMutedText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            color: selected
                ? PopqPalette.forest
                : PopqPalette.lightMutedText,
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w500,
          );
        }),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PopqPalette.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PopqPalette.forest,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(
            color: PopqPalette.forest,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PopqPalette.forest,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: PopqPalette.mist,
        selectedColor: PopqPalette.lime.withValues(alpha: 0.45),
        side: const BorderSide(
          color: PopqPalette.lightBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          color: PopqPalette.ink,
          fontWeight: FontWeight.w700,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: PopqPalette.lightBorder,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: PopqPalette.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PopqPalette.lightCard,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: PopqPalette.lightMutedText,
        ),
        hintStyle: const TextStyle(
          color: PopqPalette.lightMutedText,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.forest,
            width: 1.5,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: PopqPalette.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: PopqPalette.ink,
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineSmall: TextStyle(
          color: PopqPalette.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: PopqPalette.ink,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: PopqPalette.ink,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: PopqPalette.ink,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: PopqPalette.ink,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: PopqPalette.lightMutedText,
          height: 1.4,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PopqPalette.lime,
      brightness: Brightness.dark,
    ).copyWith(
      primary: PopqPalette.lime,
      onPrimary: PopqPalette.night,
      secondary: PopqPalette.purple,
      onSecondary: Colors.white,
      tertiary: PopqPalette.coral,
      onTertiary: PopqPalette.night,
      surface: PopqPalette.nightSurface,
      onSurface: PopqPalette.nightText,
      outline: PopqPalette.nightBorder,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PopqPalette.night,

      appBarTheme: const AppBarTheme(
        backgroundColor: PopqPalette.night,
        foregroundColor: PopqPalette.nightText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: PopqPalette.nightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: PopqPalette.nightBorder,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PopqPalette.nightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PopqPalette.lime.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected
                ? PopqPalette.lime
                : PopqPalette.nightMutedText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            color: selected
                ? PopqPalette.lime
                : PopqPalette.nightMutedText,
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w500,
          );
        }),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PopqPalette.lime,
          foregroundColor: PopqPalette.night,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PopqPalette.lime,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(
            color: PopqPalette.nightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PopqPalette.lime,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: PopqPalette.nightElevated,
        selectedColor: PopqPalette.purple.withValues(alpha: 0.34),
        side: const BorderSide(
          color: PopqPalette.nightBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          color: PopqPalette.nightText,
          fontWeight: FontWeight.w700,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: PopqPalette.nightBorder,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: PopqPalette.nightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PopqPalette.nightCard,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PopqPalette.nightSurface,
        labelStyle: const TextStyle(
          color: PopqPalette.nightMutedText,
        ),
        hintStyle: const TextStyle(
          color: PopqPalette.nightMutedText,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.nightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.nightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.lime,
            width: 1.5,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: PopqPalette.nightElevated,
        contentTextStyle: const TextStyle(
          color: PopqPalette.nightText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: PopqPalette.nightText,
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineSmall: TextStyle(
          color: PopqPalette.nightText,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: PopqPalette.nightText,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: PopqPalette.nightText,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: PopqPalette.nightText,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: PopqPalette.nightText,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: PopqPalette.nightMutedText,
          height: 1.4,
        ),
      ),
    );
  }
}