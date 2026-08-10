import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'store_discovery_repository.dart';

enum StoreSection { info, products, announcements, reviews }

class StoreSectionTopBar extends StatelessWidget {
  const StoreSectionTopBar({
    required this.store,
    required this.selected,
    super.key,
  });

  final CustomerStore store;
  final StoreSection selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StoreSectionHeader(store: store),
          StoreSectionTabs(storeId: store.storeId, selected: selected),
        ],
      ),
    );
  }
}

class StoreBackButton extends StatelessWidget {
  const StoreBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '뒤로 가기',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(CustomerRoutes.discover);
        }
      },
    );
  }
}

void openStoreSection(BuildContext context, int storeId, StoreSection section) {
  final String path = storeSectionPath(storeId, section);
  context.pushReplacement(path);
}

String storeSectionPath(int storeId, StoreSection section) => switch (section) {
  StoreSection.info => '${CustomerRoutes.stores}/$storeId',
  StoreSection.products => '${CustomerRoutes.stores}/$storeId/products',
  StoreSection.announcements =>
    '${CustomerRoutes.stores}/$storeId/announcements',
  StoreSection.reviews => '${CustomerRoutes.stores}/$storeId/reviews',
};

class StoreSectionHeader extends StatelessWidget {
  const StoreSectionHeader({required this.store, super.key});

  final CustomerStore store;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PopqSpacing.md,
          vertical: PopqSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundImage: store.imageUrl?.trim().isNotEmpty == true
                  ? NetworkImage(store.imageUrl!)
                  : null,
              child: store.imageUrl?.trim().isNotEmpty == true
                  ? null
                  : const Icon(Icons.storefront_outlined),
            ),
            const SizedBox(width: PopqSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    <String>[
                      if (store.representativeCategory?.trim().isNotEmpty ==
                          true)
                        store.representativeCategory!,
                      _businessStatusLabel(store.businessStatus),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'PRE_OPEN' => '영업 준비 중',
    'CLOSED' => '영업 종료',
    _ => status,
  };
}

class StoreSectionTabs extends StatelessWidget {
  const StoreSectionTabs({
    required this.storeId,
    required this.selected,
    super.key,
  });

  final int storeId;
  final StoreSection selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Row(
        children: StoreSection.values
            .map((StoreSection section) {
              final bool isSelected = section == selected;
              final String label = switch (section) {
                StoreSection.info => '정보',
                StoreSection.products => '상품',
                StoreSection.announcements => '공지',
                StoreSection.reviews => '리뷰',
              };
              return Expanded(
                child: InkWell(
                  onTap: isSelected
                      ? null
                      : () => openStoreSection(context, storeId, section),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? colors.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
