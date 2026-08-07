import 'package:flutter/material.dart';

import '../popq_theme.dart';

/// 홈 화면 "인기 랭킹" 섹션과 동일한 매장 카테고리 라벨입니다.
const List<String> popqStoreCategoryLabels = <String>[
  '전체',
  '식당',
  '팝업스토어',
  '플리마켓',
  '푸드트럭',
  '카페',
];

/// 홈 화면의 카테고리 탭 UI(구분선으로 나뉜 텍스트 탭 목록)를 그대로 재사용하기 위한
/// 공용 위젯입니다.
class PopqCategoryTabsRow extends StatelessWidget {
  const PopqCategoryTabsRow({
    required this.selectedIndex,
    required this.onSelected,
    this.labels = popqStoreCategoryLabels,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accent = isDark ? PopqPalette.lime : PopqPalette.forest;
    final muted = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(
                  horizontal: PopqSpacing.sm,
                ),
                color: muted.withValues(alpha: 0.4),
              ),
            _PopqCategoryTabButton(
              label: labels[index],
              selected: index == selectedIndex,
              accent: accent,
              muted: muted,
              onTap: () => onSelected(index),
            ),
          ],
        ],
      ),
    );
  }
}

class _PopqCategoryTabButton extends StatelessWidget {
  const _PopqCategoryTabButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PopqSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? accent : muted,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: PopqSpacing.xs),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: selected ? 20 : 0,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
