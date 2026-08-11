import 'package:flutter/material.dart';

class AnnouncementPinnedBadge extends StatelessWidget {
  const AnnouncementPinnedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '고정',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
