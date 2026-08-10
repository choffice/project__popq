import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../profile/customer_engagement_repository.dart';

class CustomerFavoriteStoreScreen extends StatefulWidget {
  const CustomerFavoriteStoreScreen({
    required this.repository,
    super.key,
  });

  final CustomerEngagementRepository repository;

  @override
  State<CustomerFavoriteStoreScreen> createState() =>
      _CustomerFavoriteStoreScreenState();
}

class _CustomerFavoriteStoreScreenState
    extends State<CustomerFavoriteStoreScreen> {
  static const Duration _snackBarDuration =
  Duration(seconds: 3);

  List<InterestedStore> _stores = const [];

  final Set<int> _removingStoreIds = <int>{};

  bool _isLoading = true;
  Object? _loadError;

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
      final stores =
      await widget.repository.findInterests();

      if (!mounted) {
        return;
      }

      setState(() {
        _stores = List.unmodifiable(stores);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _stores.isEmpty) {
      return const PopqLoadingView(
        message: '李쒗븳 留ㅼ옣??遺덈윭?ㅺ퀬 ?덉뼱??',
      );
    }

    if (_loadError != null && _stores.isEmpty) {
      return PopqErrorView(
        message: '李쒗븳 留ㅼ옣??遺덈윭?ㅼ? 紐삵뻽?댁슂.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          PopqSpacing.md,
          PopqSpacing.sm,
          PopqSpacing.md,
          PopqSpacing.xl,
        ),
        children: [
          if (_isLoading) ...[
            const LinearProgressIndicator(
              minHeight: 3,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
          ],
          const _FavoriteHeader(),
          const SizedBox(
            height: PopqSpacing.lg,
          ),
          if (_loadError != null) ...[
            _FavoriteLoadNotice(
              onRetry: _load,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
          ],
          if (_stores.isEmpty)
            _FavoriteEmptyView(
              onDiscoverPressed: () {
                context.go(
                  CustomerRoutes.discover,
                );
              },
            )
          else ...[
            Text(
              '珥?${_stores.length}怨?,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            for (final store in _stores)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: PopqSpacing.sm,
                ),
                child: _FavoriteStoreCard(
                  store: store,
                  isRemoving:
                  _removingStoreIds.contains(
                    store.storeId,
                  ),
                  onTap: () {
                    context.push(
                      '${CustomerRoutes.stores}/${store.storeId}',
                    );
                  },
                  onRemovePressed: () {
                    _removeInterest(store);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _removeInterest(
      InterestedStore store,
      ) async {
    if (_removingStoreIds.contains(
      store.storeId,
    )) {
      return;
    }

    setState(() {
      _removingStoreIds.add(
        store.storeId,
      );
    });

    try {
      await widget.repository.removeInterest(
        store.storeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stores = List.unmodifiable(
          _stores.where(
                (item) =>
            item.storeId != store.storeId,
          ),
        );
      });

      final messenger =
      ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text(
              '${store.name}??瑜? 李쒖뿉????젣?덉뼱??',
            ),
            duration: _snackBarDuration,

            // action???덉뼱??3珥????먮룞?쇰줈 ?щ씪吏寃??⑸땲??
            persist: false,

            action: SnackBarAction(
              label: '?섎룎由ш린',
              onPressed: () {
                unawaited(
                  _restoreInterest(store),
                );
              },
            ),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }

      final messenger =
      ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '李쒖쓣 ??젣?섏? 紐삵뻽?댁슂. ?좎떆 ???ㅼ떆 ?쒕룄??二쇱꽭??',
            ),
            duration: _snackBarDuration,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _removingStoreIds.remove(
            store.storeId,
          );
        });
      }
    }
  }

  Future<void> _restoreInterest(
      InterestedStore store,
      ) async {
    try {
      await widget.repository.addInterest(
        store.storeId,
      );

      if (!mounted) {
        return;
      }

      final alreadyExists = _stores.any(
            (item) =>
        item.storeId == store.storeId,
      );

      if (alreadyExists) {
        return;
      }

      setState(() {
        _stores = List.unmodifiable(
          [
            store,
            ..._stores,
          ],
        );
      });

      final messenger =
      ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text(
              '${store.name}??瑜? ?ㅼ떆 李쒗뻽?댁슂.',
            ),
            duration: _snackBarDuration,
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }

      final messenger =
      ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '李쒖쓣 ?ㅼ떆 ?깅줉?섏? 紐삵뻽?댁슂.',
            ),
            duration: _snackBarDuration,
          ),
        );
    }
  }
}

class _FavoriteHeader extends StatelessWidget {
  const _FavoriteHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(
        PopqSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? PopqPalette.purple.withValues(
          alpha: 0.22,
        )
            : PopqPalette.coral.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(
          26,
        ),
        border: Border.all(
          color: isDark
              ? PopqPalette.purple.withValues(
            alpha: 0.42,
          )
              : PopqPalette.coral.withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? PopqPalette.lime.withValues(
                alpha: 0.14,
              )
                  : PopqPalette.lime.withValues(
                alpha: 0.55,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: 32,
              color: isDark
                  ? PopqPalette.lime
                  : PopqPalette.forest,
            ),
          ),
          const SizedBox(
            width: PopqSpacing.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '?닿? 李쒗븳 留ㅼ옣',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: PopqSpacing.xs,
                ),
                Text(
                  '?ㅼ떆 諛⑸Ц?섍퀬 ?띠? 留ㅼ옣???쒓납?먯꽌 ?뺤씤?섏꽭??',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: isDark
                        ? PopqPalette
                        .nightMutedText
                        : PopqPalette
                        .lightMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteLoadNotice
    extends StatelessWidget {
  const _FavoriteLoadNotice({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? PopqPalette.purple.withValues(
          alpha: 0.14,
        )
            : PopqPalette.coral.withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: isDark
              ? PopqPalette.purple.withValues(
            alpha: 0.32,
          )
              : PopqPalette.coral.withValues(
            alpha: 0.24,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
          ),
          const SizedBox(
            width: PopqSpacing.sm,
          ),
          const Expanded(
            child: Text(
              '?덈줈??李?紐⑸줉??遺덈윭?ㅼ? 紐삵뻽?댁슂. ?꾩옱 紐⑸줉???쒖떆?섍퀬 ?덉뼱??',
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '?ъ떆??,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteEmptyView
    extends StatelessWidget {
  const _FavoriteEmptyView({
    required this.onDiscoverPressed,
  });

  final VoidCallback onDiscoverPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PopqSpacing.lg,
        vertical: 48,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? PopqPalette.nightCard
            : PopqPalette.lightCard,
        borderRadius: BorderRadius.circular(
          26,
        ),
        border: Border.all(
          color: isDark
              ? PopqPalette.nightBorder
              : PopqPalette.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: isDark
                  ? PopqPalette.purple.withValues(
                alpha: 0.2,
              )
                  : PopqPalette.coral.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 40,
              color: isDark
                  ? PopqPalette.lime
                  : PopqPalette.coral,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.md,
          ),
          Text(
            '?꾩쭅 李쒗븳 留ㅼ옣???놁뼱??',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          Text(
            '愿???덈뒗 留ㅼ옣???섑듃瑜??꾨Ⅴ硫?n?닿납?먯꽌 鍮좊Ⅴ寃??ㅼ떆 李얠쓣 ???덉뼱??',
            textAlign: TextAlign.center,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: isDark
                  ? PopqPalette.nightMutedText
                  : PopqPalette.lightMutedText,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.lg,
          ),
          FilledButton.icon(
            onPressed: onDiscoverPressed,
            icon: const Icon(
              Icons.search_rounded,
            ),
            label: const Text(
              '留ㅼ옣 ?섎윭蹂닿린',
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteStoreThumbnail extends StatelessWidget {
  const _FavoriteStoreThumbnail({
    required this.width,
    required this.height,
    required this.imageUrl,
    required this.isDark,
  });

  final double width;
  final double height;
  final String? imageUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';
    return SizedBox(
      width: width,
      height: height,
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
          color: isDark ? PopqPalette.lime : PopqPalette.forest,
        ),
      ),
    );
  }
}

class _FavoriteStoreCard
    extends StatelessWidget {
  const _FavoriteStoreCard({
    required this.store,
    required this.isRemoving,
    required this.onTap,
    required this.onRemovePressed,
  });

  final InterestedStore store;
  final bool isRemoving;
  final VoidCallback onTap;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(
            PopqSpacing.md,
          ),
          child: Row(
            children: [
              _FavoriteStoreThumbnail(
                width: 76,
                height: 76,
                imageUrl: store.imageUrl,
                isDark: isDark,
              ),
              const SizedBox(
                width: PopqSpacing.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight
                                  .w900,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: PopqSpacing.sm,
                        ),
                        _BusinessStatusBadge(
                          businessStatus:
                          store.businessStatus,
                        ),
                      ],
                    ),
                    if (store.representativeCategory?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: PopqSpacing.xs),
                      Text(
                        store.representativeCategory!,
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Text(
                      store.description
                          ?.trim()
                          .isNotEmpty ==
                          true
                          ? store.description!
                          : '留ㅼ옣 ?곸꽭?먯꽌 硫붾돱? ?뺣낫瑜??뺤씤??蹂댁꽭??',
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: isDark
                            ? PopqPalette
                            .nightMutedText
                            : PopqPalette
                            .lightMutedText,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: isDark
                              ? PopqPalette.lime
                              : PopqPalette.coral,
                        ),
                        const SizedBox(
                          width: PopqSpacing.xs,
                        ),
                        Expanded(
                          child: Text(
                            store.fullAddress.isEmpty
                                ? '二쇱냼 ?뺣낫 ?놁쓬'
                                : store.fullAddress,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              if (isRemoving)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(
                      13,
                    ),
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: '李???젣',
                  onPressed: onRemovePressed,
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: PopqPalette.coral,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessStatusBadge
    extends StatelessWidget {
  const _BusinessStatusBadge({
    required this.businessStatus,
  });

  final String businessStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final isOpen =
        businessStatus == 'OPEN';

    final label = switch (businessStatus) {
      'OPEN' => '?곸뾽 以?,
      'PRE_OPEN' => '?곸뾽 以鍮?,
      'CLOSED' => '?곸뾽 醫낅즺',
      'TEMPORARILY_CLOSED' => '?꾩떆 ?대Т',
      _ => businessStatus,
    };

    final foregroundColor = isOpen
        ? isDark
        ? PopqPalette.lime
        : PopqPalette.forest
        : isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    final backgroundColor = isOpen
        ? isDark
        ? PopqPalette.lime.withValues(
      alpha: 0.12,
    )
        : PopqPalette.lime.withValues(
      alpha: 0.42,
    )
        : isDark
        ? PopqPalette.nightElevated
        : PopqPalette.mist;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          999,
        ),
      ),
      child: Text(
        label,
        style: theme
            .textTheme
            .labelSmall
            ?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

