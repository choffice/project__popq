import 'package:flutter/material.dart';

import '../popq_theme.dart';

class PopqLoadingView extends StatelessWidget {
  const PopqLoadingView({this.message = '불러오는 중입니다.', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: PopqSpacing.md),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class PopqErrorView extends StatelessWidget {
  const PopqErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: PopqPalette.coral,
            ),
            const SizedBox(height: PopqSpacing.md),
            Text(
              '잠시 문제가 생겼어요.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PopqSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: PopqSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PopqEmptyView extends StatelessWidget {
  const PopqEmptyView({
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: PopqPalette.forest),
            const SizedBox(height: PopqSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PopqSpacing.sm),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
