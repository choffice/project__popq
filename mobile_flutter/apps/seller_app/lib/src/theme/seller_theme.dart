import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

@immutable
class SellerStatusColors
    extends ThemeExtension<SellerStatusColors> {
  const SellerStatusColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
  });

  const SellerStatusColors.light()
      : success = const Color(0xFF16803C),
        successContainer = const Color(0xFFE5F7EA),
        onSuccessContainer = const Color(0xFF0A5426),
        warning = const Color(0xFFE8790C),
        warningContainer = const Color(0xFFFFEEDB),
        onWarningContainer = const Color(0xFF8A4200),
        danger = const Color(0xFFD92D20),
        dangerContainer = const Color(0xFFFFE8E5),
        onDangerContainer = const Color(0xFF8A1C13);

  const SellerStatusColors.dark()
      : success = const Color(0xFF58D985),
        successContainer = const Color(0xFF123C24),
        onSuccessContainer = const Color(0xFFB8F2CA),
        warning = const Color(0xFFFFAD4D),
        warningContainer = const Color(0xFF4A2B0C),
        onWarningContainer = const Color(0xFFFFD7A3),
        danger = const Color(0xFFFF8A80),
        dangerContainer = const Color(0xFF4D1D1A),
        onDangerContainer = const Color(0xFFFFC7C2);

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;

  @override
  SellerStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
  }) {
    return SellerStatusColors(
      success: success ?? this.success,
      successContainer:
      successContainer ?? this.successContainer,
      onSuccessContainer:
      onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer:
      warningContainer ?? this.warningContainer,
      onWarningContainer:
      onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      dangerContainer:
      dangerContainer ?? this.dangerContainer,
      onDangerContainer:
      onDangerContainer ?? this.onDangerContainer,
    );
  }

  @override
  SellerStatusColors lerp(
      covariant SellerStatusColors? other,
      double t,
      ) {
    if (other == null) {
      return this;
    }

    return SellerStatusColors(
      success: Color.lerp(
        success,
        other.success,
        t,
      )!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(
        warning,
        other.warning,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      danger: Color.lerp(
        danger,
        other.danger,
        t,
      )!,
      dangerContainer: Color.lerp(
        dangerContainer,
        other.dangerContainer,
        t,
      )!,
      onDangerContainer: Color.lerp(
        onDangerContainer,
        other.onDangerContainer,
        t,
      )!,
    );
  }
}

abstract final class SellerTheme {
  static const Color _softLime =
  Color(0xFFD4EF55);

  static ThemeData light() {
    final base = PopqTheme.light();

    final colorScheme = base.colorScheme.copyWith(
      primary: PopqPalette.lime,
      onPrimary: PopqPalette.ink,
      primaryContainer: const Color(0xFFE9FF9D),
      onPrimaryContainer: PopqPalette.ink,
      secondary: PopqPalette.purple,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEDE4FF),
      onSecondaryContainer: PopqPalette.ink,
      tertiary: PopqPalette.coral,
      onTertiary: PopqPalette.ink,
      surface: PopqPalette.mist,
      onSurface: PopqPalette.ink,
      outline: PopqPalette.lightBorder,
      error: const Color(0xFFD92D20),
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PopqPalette.mist,

      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: PopqPalette.mist,
        foregroundColor: PopqPalette.ink,
        surfaceTintColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PopqPalette.lightCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PopqPalette.lime,
        iconTheme: WidgetStateProperty.resolveWith(
              (states) {
            final selected =
            states.contains(WidgetState.selected);

            return IconThemeData(
              color: selected
                  ? PopqPalette.ink
                  : PopqPalette.lightMutedText,
            );
          },
        ),
        labelTextStyle:
        WidgetStateProperty.resolveWith(
              (states) {
            final selected =
            states.contains(WidgetState.selected);

            return TextStyle(
              color: selected
                  ? PopqPalette.ink
                  : PopqPalette.lightMutedText,
              fontWeight: selected
                  ? FontWeight.w800
                  : FontWeight.w500,
            );
          },
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _softLime,
          foregroundColor: PopqPalette.ink,
          disabledBackgroundColor:
          PopqPalette.lightBorder,
          disabledForegroundColor:
          PopqPalette.lightMutedText,
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
          foregroundColor: PopqPalette.purple,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(
            color: PopqPalette.purple,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PopqPalette.purple,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: PopqPalette.lightCard,
        selectedColor:
        PopqPalette.lime.withValues(alpha: 0.55),
        side: const BorderSide(
          color: PopqPalette.lightBorder,
        ),
        labelStyle: const TextStyle(
          color: PopqPalette.ink,
          fontWeight: FontWeight.w700,
        ),
      ),

      inputDecorationTheme:
      base.inputDecorationTheme.copyWith(
        fillColor: PopqPalette.lightCard,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.purple,
            width: 1.6,
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) {
            return states.contains(
              WidgetState.selected,
            )
                ? PopqPalette.ink
                : PopqPalette.lightMutedText;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith(
              (states) {
            return states.contains(
              WidgetState.selected,
            )
                ? PopqPalette.lime
                : PopqPalette.lightBorder;
          },
        ),
        trackOutlineColor:
        const WidgetStatePropertyAll(
          Colors.transparent,
        ),
      ),

      extensions: const [
        SellerStatusColors.light(),
      ],
    );
  }

  static ThemeData dark() {
    final base = PopqTheme.dark();

    final colorScheme = base.colorScheme.copyWith(
      primary: PopqPalette.lime,
      onPrimary: PopqPalette.night,
      primaryContainer: const Color(0xFF314100),
      onPrimaryContainer: const Color(0xFFE8FF91),
      secondary: PopqPalette.purple,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF332255),
      onSecondaryContainer: const Color(0xFFE8DFFF),
      tertiary: PopqPalette.coral,
      onTertiary: PopqPalette.night,
      surface: PopqPalette.nightSurface,
      onSurface: PopqPalette.nightText,
      outline: PopqPalette.nightBorder,
      error: const Color(0xFFFF8A80),
      onError: PopqPalette.night,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PopqPalette.night,

      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: PopqPalette.night,
        foregroundColor: PopqPalette.nightText,
        surfaceTintColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PopqPalette.nightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PopqPalette.lime.withValues(
          alpha: 0.22,
        ),
        iconTheme: WidgetStateProperty.resolveWith(
              (states) {
            final selected =
            states.contains(WidgetState.selected);

            return IconThemeData(
              color: selected
                  ? PopqPalette.lime
                  : PopqPalette.nightMutedText,
            );
          },
        ),
        labelTextStyle:
        WidgetStateProperty.resolveWith(
              (states) {
            final selected =
            states.contains(WidgetState.selected);

            return TextStyle(
              color: selected
                  ? PopqPalette.lime
                  : PopqPalette.nightMutedText,
              fontWeight: selected
                  ? FontWeight.w800
                  : FontWeight.w500,
            );
          },
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PopqPalette.lime,
          foregroundColor: PopqPalette.night,
          disabledBackgroundColor:
          PopqPalette.nightElevated,
          disabledForegroundColor:
          PopqPalette.nightMutedText,
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
          foregroundColor: PopqPalette.purple,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(
            color: PopqPalette.purple,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PopqPalette.lime,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: PopqPalette.nightElevated,
        selectedColor:
        PopqPalette.purple.withValues(alpha: 0.38),
        side: const BorderSide(
          color: PopqPalette.nightBorder,
        ),
        labelStyle: const TextStyle(
          color: PopqPalette.nightText,
          fontWeight: FontWeight.w700,
        ),
      ),

      inputDecorationTheme:
      base.inputDecorationTheme.copyWith(
        fillColor: PopqPalette.nightSurface,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: PopqPalette.lime,
            width: 1.6,
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) {
            return states.contains(
              WidgetState.selected,
            )
                ? PopqPalette.night
                : PopqPalette.nightMutedText;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith(
              (states) {
            return states.contains(
              WidgetState.selected,
            )
                ? PopqPalette.lime
                : PopqPalette.nightBorder;
          },
        ),
        trackOutlineColor:
        const WidgetStatePropertyAll(
          Colors.transparent,
        ),
      ),

      extensions: const [
        SellerStatusColors.dark(),
      ],
    );
  }
}