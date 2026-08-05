import 'dart:math';

import 'package:flutter/material.dart';

import '../popq_theme.dart';

class PopqSplashScreen extends StatefulWidget {
  const PopqSplashScreen({super.key});

  @override
  State<PopqSplashScreen> createState() => _PopqSplashScreenState();
}

class _PopqSplashScreenState extends State<PopqSplashScreen> {
  static const _wordmarkAssets = [
    'assets/splash/logo_sub.png', // 한글 배너 (팝.큐)
    'assets/splash/logo_title.png', // 영문 배너 (POPQ)
  ];

  late final String _wordmarkAsset =
      _wordmarkAssets[Random().nextInt(_wordmarkAssets.length)];

  // splash_pusky.gif is a 540x540 square image.
  static const double _gifAspectRatio = 1;

  // logo_sub.png / logo_title.png are both close to a ~2.27:1 width:height
  // ratio, so a single reserved height keeps either pick from letterboxing.
  static const double _wordmarkAspectRatio = 0.44;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final gifWidth = screenWidth * 0.62 > 340 ? 340.0 : screenWidth * 0.62;
    final gifHeight = gifWidth / _gifAspectRatio;
    final wordmarkHeight = gifWidth * _wordmarkAspectRatio;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: const Alignment(0, 0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: gifWidth,
                height: wordmarkHeight,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _PopqWordmark(
                    assetPath: _wordmarkAsset,
                    brightness: Theme.of(context).brightness,
                  ),
                ),
              ),
              Image.asset(
                'assets/splash/splash_pusky.gif',
                package: 'popq_design_system',
                width: gifWidth,
                height: gifHeight,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: PopqSpacing.xs),
              SizedBox(
                width: gifWidth,
                child: Text(
                  'QR의 세계에 오신것을 환영합니다',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the POPQ wordmark artwork as-is (black fill untouched). In dark
/// mode a light outline is added behind it so the black shapes stay visible
/// against the dark background, instead of recoloring the artwork itself.
class _PopqWordmark extends StatelessWidget {
  const _PopqWordmark({required this.assetPath, required this.brightness});

  final String assetPath;
  final Brightness brightness;

  // Outline thickness in the source image's own pixel space (the artwork is
  // ~720px wide), scaled down together with the rest by the parent FittedBox.
  static const double _outlineWidth = 12;

  static const _outlineOffsets = [
    Offset(-_outlineWidth, -_outlineWidth),
    Offset(0, -_outlineWidth),
    Offset(_outlineWidth, -_outlineWidth),
    Offset(-_outlineWidth, 0),
    Offset(_outlineWidth, 0),
    Offset(-_outlineWidth, _outlineWidth),
    Offset(0, _outlineWidth),
    Offset(_outlineWidth, _outlineWidth),
  ];

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      package: 'popq_design_system',
      fit: BoxFit.contain,
    );

    if (brightness != Brightness.dark) {
      return image;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        for (final offset in _outlineOffsets)
          Transform.translate(
            offset: offset,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                PopqPalette.nightText,
                BlendMode.srcIn,
              ),
              child: image,
            ),
          ),
        image,
      ],
    );
  }
}
