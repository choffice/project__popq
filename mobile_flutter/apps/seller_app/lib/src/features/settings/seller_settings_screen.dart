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
        title: const Text('?먮ℓ???ㅼ젙'),
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
                '?붾㈃ ?ㅼ젙',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PopqSpacing.sm),
              _ThemeSettingsCard(
                controller: themeController,
              ),
              const SizedBox(height: PopqSpacing.xl),
              Text(
                '???뺣낫',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PopqSpacing.sm),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.storefront_rounded),
                      title: Text('POPQ ?먮ℓ??),
                      subtitle: Text('二쇰Ц怨?留ㅼ옣 ?댁쁺??愿由ы븯????),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('??踰꾩쟾'),
                      trailing: Text('媛쒕컻 踰꾩쟾'),
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
                  'POPQ ?먮ℓ??,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '留ㅼ옣 ?댁쁺 ?섍꼍???ㅼ젙?섏꽭??',
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
                        '???뚮쭏',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: PopqSpacing.xs),
                      Text(
                        '?먮ℓ???깆쓽 ?붾㈃ 紐⑤뱶瑜??좏깮?섏꽭??',
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
                    label: Text('湲곕낯 紐⑤뱶'),
                  ),
                  ButtonSegment(
                    value: PopqThemePreference.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('?ㅽ겕 紐⑤뱶'),
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
          content: Text('?붾㈃ ?ㅼ젙????ν븯吏 紐삵뻽?댁슂.'),
        ),
      );
    }
  }
}
