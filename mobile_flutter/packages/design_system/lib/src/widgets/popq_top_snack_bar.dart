import 'dart:async';

import 'package:flutter/material.dart';

/// POPQ 怨듯넻 ?곷떒 ?뚮┝.
///
/// 湲곗〈 [SnackBar] 媛앹껜瑜?洹몃?濡?諛쏆븘 ?댁슜, ?≪뀡, 吏?띿떆媛꾩쓣 ?좎??섎㈃??/// ?붾㈃ ?섎떒???꾨땶 ?곷떒 SafeArea ?곸뿭???쒖떆?쒕떎.
class PopqTopSnackBar {
  PopqTopSnackBar._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(BuildContext context, SnackBar snackBar) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _PopqTopSnackBarView(
              snackBar: snackBar,
              onDismiss: hide,
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(snackBar.duration, hide);
  }

  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    final entry = _currentEntry;
    _currentEntry = null;
    entry?.remove();
  }
}

extension PopqTopSnackBarMessengerExtension on ScaffoldMessengerState {
  void showTopSnackBar(SnackBar snackBar) {
    PopqTopSnackBar.show(context, snackBar);
  }

  void hideCurrentTopSnackBar() {
    PopqTopSnackBar.hide();
  }
}

class _PopqTopSnackBarView extends StatelessWidget {
  const _PopqTopSnackBarView({
    required this.snackBar,
    required this.onDismiss,
  });

  final SnackBar snackBar;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snackBarTheme = theme.snackBarTheme;

    final backgroundColor =
        snackBar.backgroundColor ??
        snackBarTheme.backgroundColor ??
        colorScheme.inverseSurface;

    final contentTextStyle =
        snackBarTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        );

    final action = snackBar.action;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: -14, end: 0),
      builder: (context, offsetY, child) {
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: child,
        );
      },
      child: Material(
        color: backgroundColor,
        elevation: snackBar.elevation ?? snackBarTheme.elevation ?? 6,
        shadowColor: Colors.black26,
        shape:
            snackBar.shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding:
              snackBar.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: contentTextStyle,
                  child: snackBar.content,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        action.textColor ?? colorScheme.inversePrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    onDismiss();
                    action.onPressed();
                  },
                  child: Text(action.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
