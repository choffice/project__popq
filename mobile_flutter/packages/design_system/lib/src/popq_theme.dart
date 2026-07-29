import 'package:flutter/material.dart';

abstract final class PopqPalette {
  static const ink = Color(0xFF17231F);
  static const forest = Color(0xFF174D3B);
  static const coral = Color(0xFFFF6B52);
  static const lime = Color(0xFFCBEA77);
  static const cream = Color(0xFFFFF8EB);
  static const mist = Color(0xFFF1F5F2);
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
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: PopqPalette.forest,
          brightness: Brightness.light,
          surface: PopqPalette.cream,
        ).copyWith(
          primary: PopqPalette.forest,
          secondary: PopqPalette.coral,
          tertiary: PopqPalette.lime,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PopqPalette.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: PopqPalette.cream,
        foregroundColor: PopqPalette.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: PopqPalette.ink.withValues(alpha: 0.08)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: PopqPalette.lime.withValues(alpha: 0.55),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? PopqPalette.ink
                : PopqPalette.ink.withValues(alpha: 0.58),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
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
        bodyLarge: TextStyle(color: PopqPalette.ink, fontSize: 16, height: 1.5),
      ),
    );
  }
}
