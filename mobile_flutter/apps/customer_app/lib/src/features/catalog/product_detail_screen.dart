import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import '../discovery/store_discovery_repository.dart';
import 'catalog_repository.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.storeId,
    required this.productId,
    required this.repository,
    required this.storeDiscoveryRepository,
    required this.cartController,
    super.key,
  });

  final int storeId;
  final int productId;
  final CatalogRepository repository;
  final StoreDiscoveryRepository storeDiscoveryRepository;
  final CartController cartController;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<CatalogProduct> _product;
  late Future<CustomerStore> _store;
  final Map<int, Set<int>> _selected = {};
  var _quantity = 1;
  var _addingToCart = false;

  @override
  void initState() {
    super.initState();
    _product = widget.repository.findProduct(widget.storeId, widget.productId);
    _store = widget.storeDiscoveryRepository.findDetail(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('?곹뭹 ?좏깮'),
        actions: [
          IconButton(
            tooltip: '?λ컮援щ땲',
            onPressed: () => context.push(CustomerRoutes.cart),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: FutureBuilder<CatalogProduct>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '?곹뭹 ?뺣낫瑜?遺덈윭?ㅺ퀬 ?덉뼱??');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '?곹뭹 ?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??',
              onRetry: () => setState(() {
                _product = widget.repository.findProduct(
                  widget.storeId,
                  widget.productId,
                );
              }),
            );
          }
          final product = snapshot.requireData;
          return FutureBuilder<CustomerStore>(
            future: _store,
            builder: (context, storeSnapshot) {
              final store = storeSnapshot.data;
              final checkingStore =
                  storeSnapshot.connectionState != ConnectionState.done;
              final storeLoadFailed = storeSnapshot.hasError ||
                  (storeSnapshot.connectionState == ConnectionState.done &&
                      store == null);
              final orderPaused =
                  store != null && !store.orderAcceptingEnabled;

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(PopqSpacing.lg),
                      children: [
                        if (orderPaused) ...[
                          const _OrderPausedBanner(),
                          const SizedBox(height: PopqSpacing.md),
                        ] else if (storeLoadFailed) ...[
                          _StoreStatusError(
                            onRetry: () {
                              setState(() {
                                _store = widget.storeDiscoveryRepository
                                    .findDetail(widget.storeId);
                              });
                            },
                          ),
                          const SizedBox(height: PopqSpacing.md),
                        ],
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: PopqPalette.lime,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.local_cafe_rounded,
                        size: 72,
                        color: PopqPalette.forest,
                      ),
                    ),
                    const SizedBox(height: PopqSpacing.lg),
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: PopqSpacing.xs),
                    Text(_won(product.basePrice)),
                    if (product.description != null) ...[
                      const SizedBox(height: PopqSpacing.md),
                      Text(product.description!),
                    ],
                    for (final group in product.optionGroups) ...[
                      const SizedBox(height: PopqSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            group.required
                                ? '?꾩닔 ${group.minSelect}媛?
                                : '理쒕? ${group.maxSelect}媛?,
                          ),
                        ],
                      ),
                      for (final option in group.options)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value:
                              _selected[group.optionGroupId]?.contains(
                                option.optionId,
                              ) ??
                              false,
                          title: Text(option.name),
                          subtitle: option.additionalPrice == 0
                              ? null
                              : Text('+${_won(option.additionalPrice)}'),
                          onChanged: (_) => _toggle(group, option),
                        ),
                    ],
                    const SizedBox(height: PopqSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PopqSpacing.lg,
                          ),
                          child: Text(
                            '$_quantity',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _quantity < 99
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(PopqSpacing.md),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: !checkingStore &&
                                  !storeLoadFailed &&
                                  !orderPaused &&
                                  !_addingToCart &&
                                  product.availableForCustomerApp &&
                                  _isSelectionValid(product)
                              ? () => _addToCart(product)
                              : null,
                          child: Text(
                            checkingStore
                                ? '二쇰Ц 媛???щ? ?뺤씤 以?..'
                                : storeLoadFailed
                                    ? '二쇰Ц ?곹깭瑜??뺤씤?댁＜?몄슂'
                                    : orderPaused
                                        ? '?꾩옱 二쇰Ц ?묒닔 以묒?'
                                        : _addingToCart
                                            ? '二쇰Ц ?곹깭 ?뺤씤 以?..'
                                            : '${_won(_total(product))} 쨌 ?λ컮援щ땲 ?닿린',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _toggle(ProductOptionGroup group, ProductOption option) {
    setState(() {
      final values = _selected.putIfAbsent(group.optionGroupId, () => <int>{});
      if (values.remove(option.optionId)) return;
      if (group.maxSelect == 1) values.clear();
      if (values.length < group.maxSelect) values.add(option.optionId);
    });
  }

  bool _isSelectionValid(CatalogProduct product) {
    for (final group in product.optionGroups) {
      final count = _selected[group.optionGroupId]?.length ?? 0;
      if (count < group.minSelect || count > group.maxSelect) return false;
    }
    return true;
  }

  List<ProductOption> _selectedOptions(CatalogProduct product) {
    final ids = _selected.values.expand((values) => values).toSet();
    return product.optionGroups
        .expand((group) => group.options)
        .where((option) => ids.contains(option.optionId))
        .toList();
  }

  int _total(CatalogProduct product) {
    final optionAmount = _selectedOptions(
      product,
    ).fold(0, (sum, option) => sum + option.additionalPrice);
    return (product.basePrice + optionAmount) * _quantity;
  }

  Future<void> _addToCart(CatalogProduct product) async {
    if (_addingToCart) {
      return;
    }

    setState(() {
      _addingToCart = true;
    });

    try {
      final store = await widget.storeDiscoveryRepository.findDetail(
        widget.storeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _store = Future<CustomerStore>.value(store);
      });

      if (!store.orderAcceptingEnabled) {
        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(
            content: Text('?꾩옱 留ㅼ옣???좉퇋 二쇰Ц ?묒닔瑜??좎떆 以묒??덉뼱??'),
          ),
        );
        return;
      }

      final options = _selectedOptions(product);
      try {
        widget.cartController.add(
        targetStoreId: widget.storeId,
        product: product,
        options: options,
        quantity: _quantity,
      );
    } on CartStoreConflict {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('?ㅻⅨ ?ㅽ넗???곹뭹???덉뼱??'),
            content: const Text('湲곗〈 ?λ컮援щ땲瑜?鍮꾩슦怨????곹뭹???댁쓣源뚯슂?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('痍⑥냼'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('鍮꾩슦怨??닿린'),
              ),
            ],
          );
        },
      );
      if (replace != true) return;
      widget.cartController.replaceWith(
        targetStoreId: widget.storeId,
        product: product,
        options: options,
        quantity: _quantity,
      );
    }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: const Text('?λ컮援щ땲???댁븯?듬땲??'),
          action: SnackBarAction(
            label: '蹂닿린',
            onPressed: () => context.push(CustomerRoutes.cart),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('二쇰Ц 媛???щ?瑜??뺤씤?섏? 紐삵뻽?댁슂. ?좎떆 ???ㅼ떆 ?쒕룄?댁＜?몄슂.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingToCart = false;
        });
      }
    }
  }
}


class _OrderPausedBanner extends StatelessWidget {
  const _OrderPausedBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: PopqSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '?꾩옱 二쇰Ц ?묒닔媛 ?좎떆 以묐떒?섏뿀?댁슂.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '?묒닔媛 ?ㅼ떆 ?쒖옉?섎㈃ ?λ컮援щ땲???댁쓣 ???덉뼱??',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
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

class _StoreStatusError extends StatelessWidget {
  const _StoreStatusError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded),
            const SizedBox(width: PopqSpacing.sm),
            const Expanded(
              child: Text('?꾩옱 二쇰Ц 媛???щ?瑜??뺤씤?섏? 紐삵뻽?댁슂.'),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('?ㅼ떆 ?뺤씤'),
            ),
          ],
        ),
      ),
    );
  }
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '$buffer??;
}

