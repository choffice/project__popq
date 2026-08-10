import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SellerSettingsScreen extends StatelessWidget {
  const SellerSettingsScreen({
    required this.themeController,
    super.key,
  });

  final PopqThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('판매자 설정'),
      ),
      body: AnimatedBuilder(
        animation: themeController,
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              _SellerProfileCard(
                isDarkMode: themeController.isDarkMode,
              ),
              const SizedBox(height: PopqSpacing.xl),
              Text(
                '화면 설정',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PopqSpacing.sm),
              _ThemeSettingsCard(
                controller: themeController,
              ),
              const SizedBox(height: PopqSpacing.xl),
              Text(
                '앱 정보',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PopqSpacing.sm),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.storefront_rounded),
                      title: Text('POPQ 판매자'),
                      subtitle: Text('주문과 매장 운영을 관리하는 앱'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('앱 버전'),
                      trailing: Text('개발 버전'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SellerProfileCard extends StatelessWidget {
  const _SellerProfileCard({
    required this.isDarkMode,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      decoration: BoxDecoration(
        color: isDarkMode
            ? PopqPalette.nightCard
            : PopqPalette.forest,
        borderRadius: BorderRadius.circular(24),
        border: isDarkMode
            ? Border.all(
          color: PopqPalette.nightBorder,
        )
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isDarkMode
                ? PopqPalette.lime
                : Colors.white,
            foregroundColor: isDarkMode
                ? PopqPalette.night
                : PopqPalette.forest,
            child: const Icon(
              Icons.store_rounded,
              size: 32,
            ),
          ),
          const SizedBox(width: PopqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POPQ 판매자',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '매장 운영 환경을 설정하세요.',
                  style: TextStyle(
                    color: isDarkMode
                        ? PopqPalette.nightMutedText
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isDarkMode
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: isDarkMode
                ? PopqPalette.lime
                : colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _ThemeSettingsCard extends StatelessWidget {
  const _ThemeSettingsCard({
    required this.controller,
  });

  final PopqThemeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                  Theme.of(context).colorScheme.onPrimaryContainer,
                  child: Icon(
                    controller.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                  ),
                ),
                const SizedBox(width: PopqSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '앱 테마',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: PopqSpacing.xs),
                      Text(
                        '판매자 앱의 화면 모드를 선택하세요.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PopqThemePreference>(
                segments: const [
                  ButtonSegment(
                    value: PopqThemePreference.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('기본 모드'),
                  ),
                  ButtonSegment(
                    value: PopqThemePreference.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('다크 모드'),
                  ),
                ],
                selected: {
                  controller.preference,
                },
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }

                  _changeTheme(
                    context,
                    selection.first,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeTheme(
      BuildContext context,
      PopqThemePreference preference,
      ) async {
    try {
      await controller.setPreference(preference);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('화면 설정을 저장하지 못했어요.'),
        ),
      );
    }
  }
}