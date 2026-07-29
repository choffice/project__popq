import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'catalog_repository.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    required this.storeId,
    required this.repository,
    required this.cartController,
    super.key,
  });

  final int storeId;
  final CatalogRepository repository;
  final CartController cartController;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<CatalogProduct>> _products;

  @override
  void initState() {
    super.initState();
    _products = widget.repository.findProducts(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품'),
        actions: [_CartButton(cartController: widget.cartController)],
      ),
      body: FutureBuilder<List<CatalogProduct>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '상품을 준비하고 있어요.');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '상품 목록을 불러오지 못했습니다.',
              onRetry: () => setState(() {
                _products = widget.repository.findProducts(widget.storeId);
              }),
            );
          }
          if (snapshot.requireData.isEmpty) {
            return const PopqEmptyView(
              icon: Icons.inventory_2_outlined,
              title: '판매 중인 상품이 없어요.',
              description: '새 상품이 준비되면 이곳에서 확인할 수 있습니다.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _products = widget.repository.findProducts(widget.storeId);
              });
              await _products;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(PopqSpacing.md),
              itemCount: snapshot.requireData.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PopqSpacing.sm),
              itemBuilder: (context, index) {
                final product = snapshot.requireData[index];
                return Card(
                  child: ListTile(
                    enabled: !product.soldOut,
                    contentPadding: const EdgeInsets.all(PopqSpacing.md),
                    leading: CircleAvatar(
                      backgroundColor: PopqPalette.lime,
                      child: Icon(
                        product.soldOut
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.local_cafe_outlined,
                        color: PopqPalette.forest,
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      product.soldOut
                          ? '${product.categoryName} · 품절'
                          : product.categoryName,
                    ),
                    trailing: Text(_won(product.basePrice)),
                    onTap: product.soldOut
                        ? null
                        : () => context.push(
                            '${CustomerRoutes.stores}/${widget.storeId}'
                            '/products/${product.productId}',
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CartButton extends StatefulWidget {
  const _CartButton({required this.cartController});

  final CartController cartController;

  @override
  State<_CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<_CartButton> {
  @override
  void initState() {
    super.initState();
    widget.cartController.addListener(_changed);
  }

  @override
  void dispose() {
    widget.cartController.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: widget.cartController.itemCount > 0,
      label: Text('${widget.cartController.itemCount}'),
      child: IconButton(
        tooltip: '장바구니',
        onPressed: () => context.push(CustomerRoutes.cart),
        icon: const Icon(Icons.shopping_bag_outlined),
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
