import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'catalog_repository.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.storeId,
    required this.productId,
    required this.repository,
    required this.cartController,
    super.key,
  });

  final int storeId;
  final int productId;
  final CatalogRepository repository;
  final CartController cartController;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<CatalogProduct> _product;
  final Map<int, Set<int>> _selected = {};
  var _quantity = 1;

  @override
  void initState() {
    super.initState();
    _product = widget.repository.findProduct(widget.storeId, widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 선택'),
        actions: [
          IconButton(
            tooltip: '장바구니',
            onPressed: () => context.push(CustomerRoutes.cart),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: FutureBuilder<CatalogProduct>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '상품 정보를 불러오고 있어요.');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '상품 정보를 불러오지 못했습니다.',
              onRetry: () => setState(() {
                _product = widget.repository.findProduct(
                  widget.storeId,
                  widget.productId,
                );
              }),
            );
          }
          final product = snapshot.requireData;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(PopqSpacing.lg),
                  children: [
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
                                ? '필수 ${group.minSelect}개'
                                : '최대 ${group.maxSelect}개',
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
                      onPressed:
                          product.availableForCustomerApp &&
                              _isSelectionValid(product)
                          ? () => _addToCart(product)
                          : null,
                      child: Text('${_won(_total(product))} · 장바구니 담기'),
                    ),
                  ),
                ),
              ),
            ],
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
            title: const Text('다른 스토어 상품이 있어요.'),
            content: const Text('기존 장바구니를 비우고 이 상품을 담을까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('비우고 담기'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('장바구니에 담았습니다.'),
        action: SnackBarAction(
          label: '보기',
          onPressed: () => context.push(CustomerRoutes.cart),
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
  return '$buffer원';
}
