import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'customer_engagement_repository.dart';
import 'store_category_filter.dart';

class CustomerVisitHistoryScreen extends StatefulWidget {
  const CustomerVisitHistoryScreen({
    required this.repository,
    super.key,
  });

  final CustomerEngagementRepository repository;

  @override
  State<CustomerVisitHistoryScreen> createState() =>
      _CustomerVisitHistoryScreenState();
}

class _CustomerVisitHistoryScreenState
    extends State<CustomerVisitHistoryScreen> {
  List<VisitedStore> _stores = const [];
  bool _isLoading = true;
  Object? _loadError;
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final stores = await widget.repository.findVisitedStores();

      if (!mounted) return;

      setState(() {
        _stores = List.unmodifiable(stores);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방문 기록'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _stores.isEmpty) {
      return const PopqLoadingView(
        message: '방문 기록을 불러오고 있어요.',
      );
    }

    if (_loadError != null && _stores.isEmpty) {
      return PopqErrorView(
        message: '방문 기록을 불러오지 못했어요. ($_loadError)',
        onRetry: _load,
      );
    }

    final selectedLabel =
        popqStoreCategoryLabels[_selectedCategoryIndex];

    final filteredStores = _stores
        .where(
          (store) => matchesStoreCategoryLabel(
            store.storeCategory,
            selectedLabel,
          ),
        )
        .toList();

    if (_stores.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PopqSpacing.lg,
                PopqSpacing.lg,
                PopqSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: PopqCategoryTabsRow(
                  selectedIndex: _selectedCategoryIndex,
                  onSelected: (index) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                ),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PopqEmptyView(
                icon: Icons.history_rounded,
                title: '아직 방문 기록이 없어요.',
                description: '결제까지 완료한 매장이 이곳에 기록돼요.',
              ),
            ),
          ],
        ),
      );
    }

    if (filteredStores.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PopqSpacing.lg,
                PopqSpacing.lg,
                PopqSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: PopqCategoryTabsRow(
                  selectedIndex: _selectedCategoryIndex,
                  onSelected: (index) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: PopqEmptyView(
                icon: Icons.filter_alt_off_outlined,
                title: '$selectedLabel 카테고리의 방문 기록이 없어요.',
                description: '다른 카테고리를 선택해 보세요.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: <Widget>[
          PopqCategoryTabsRow(
            selectedIndex: _selectedCategoryIndex,
            onSelected: (index) {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
          ),
          const SizedBox(
            height: PopqSpacing.md,
          ),
          Text(
            '결제까지 완료한 매장 ${filteredStores.length}곳',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          for (final store in filteredStores)
            Padding(
              padding: const EdgeInsets.only(
                bottom: PopqSpacing.sm,
              ),
              child: _VisitedStoreCard(
                store: store,
                onTap: () {
                  context.push(
                    '${CustomerRoutes.stores}/${store.storeId}',
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitedStoreThumbnail extends StatelessWidget {
  const _VisitedStoreThumbnail({
    required this.imageUrl,
    required this.isDark,
  });

  final String? imageUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';

    return SizedBox(
      width: 76,
      height: 76,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: url.isEmpty
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: isDark
          ? PopqPalette.purple.withValues(alpha: 0.2)
          : PopqPalette.lime.withValues(alpha: 0.42),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 34,
          color: isDark
              ? PopqPalette.lime
              : PopqPalette.forest,
        ),
      ),
    );
  }
}

class _VisitedStoreCard extends StatelessWidget {
  const _VisitedStoreCard({
    required this.store,
    required this.onTap,
  });

  final VisitedStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: Row(
            children: [
              _VisitedStoreThumbnail(
                imageUrl: store.storeImageUrl,
                isDark: isDark,
              ),
              const SizedBox(
                width: PopqSpacing.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),
                    Text(
                      '최근 방문 ${_formatDate(store.lastVisitedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? PopqPalette.nightMutedText
                            : PopqPalette.lightMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? PopqPalette.nightMutedText
                    : PopqPalette.lightMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();

  return '${local.year}.${local.month.toString().padLeft(2, '0')}.'
      '${local.day.toString().padLeft(2, '0')}';
}
