import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

/// 상단바에서 기본/다크 모드를 바로 전환하는 원형 버튼입니다.
///
/// 버튼이 이동하는 슬라이더가 아니라, 하나의 원 안에서
/// 해·초승달 아이콘이 바로 바뀌는 방식입니다.
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({
    required this.controller,
    super.key,
  });

  final PopqThemeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final isDark = controller.isDarkMode;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PopqSpacing.xs,
          ),
          child: Tooltip(
            message: isDark ? '다크 모드' : '기본 모드',
            child: Material(
              color: isDark
                  ? PopqPalette.lime
                  : PopqPalette.forest,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  unawaited(
                    controller.setPreference(
                      isDark
                          ? PopqThemePreference.light
                          : PopqThemePreference.dark,
                    ),
                  );
                },
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      transitionBuilder:
                          (child, animation) {
                        return RotationTransition(
                          turns: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        isDark
                            ? Icons
                            .dark_mode_rounded
                            : Icons
                            .light_mode_rounded,
                        key: ValueKey(isDark),
                        size: 18,
                        color: isDark
                            ? PopqPalette.night
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
