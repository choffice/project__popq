import 'dart:async';

import 'package:flutter/material.dart';

class PopqTopSnackBar {
  PopqTopSnackBar._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static ScaffoldMessengerState? _fallbackMessenger;

  static void show(
      ScaffoldMessengerState messenger,
      SnackBar snackBar,
      ) {
    hide();

    final overlay = _findOverlay(messenger.context);

    // Overlay를 못 찾는 특수 상황에서는 기존 SnackBar로 fallback
    if (overlay == null) {
      _fallbackMessenger = messenger;
      messenger.showSnackBar(snackBar);
      return;
    }

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final snackBarTheme = theme.snackBarTheme;

        final backgroundColor =
            snackBar.backgroundColor ??
                snackBarTheme.backgroundColor ??
                colorScheme.inverseSurface;

        final textStyle =
            snackBarTheme.contentTextStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onInverseSurface,
                );

        final action = snackBar.action;

        return Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: -20, end: 0),
              builder: (context, offsetY, child) {
                return Transform.translate(
                  offset: Offset(0, offsetY),
                  child: child,
                );
              },
              child: Material(
                color: backgroundColor,
                elevation: snackBar.elevation ?? 6,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: snackBar.padding ??
                      const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: textStyle,
                          child: snackBar.content,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor:
                            action.textColor ??
                                colorScheme.inversePrimary,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          ),
                          onPressed: () {
                            hide();
                            action.onPressed();
                          },
                          child: Text(action.label),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(snackBar.duration, hide);
  }

  static OverlayState? _findOverlay(BuildContext context) {
    final ancestorOverlay = Overlay.maybeOf(
      context,
      rootOverlay: true,
    );

    if (ancestorOverlay != null) {
      return ancestorOverlay;
    }

    OverlayState? found;

    void search(Element element) {
      if (found != null) return;

      if (element is StatefulElement &&
          element.state is OverlayState) {
        found = element.state as OverlayState;
        return;
      }

      element.visitChildren(search);
    }

    if (context is Element) {
      context.visitChildren(search);
    }

    return found;
  }

  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    final entry = _currentEntry;
    _currentEntry = null;

    if (entry != null && entry.mounted) {
      entry.remove();
    }

    final messenger = _fallbackMessenger;
    _fallbackMessenger = null;

    if (messenger != null && messenger.mounted) {
      messenger.hideCurrentSnackBar();
    }
  }
}

extension PopqTopSnackBarMessengerExtension on ScaffoldMessengerState {
  void showTopSnackBar(SnackBar snackBar) {
    PopqTopSnackBar.show(this, snackBar);
  }

  void hideCurrentTopSnackBar() {
    PopqTopSnackBar.hide();
  }
}