import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../orders/seller_order_list_screen.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_product_repository.dart';

enum _ProductFilter { all, selling, soldOut, channelOff }

class SellerProductListScreen extends StatefulWidget {
  const SellerProductListScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerProductRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerProductListScreen> createState() =>
      _SellerProductListScreenState();
}

class _SellerProductListScreenState extends State<SellerProductListScreen> {
  List<SellerProduct>? _products;
  Object? _error;
  var _loading = true;
  var _query = '';
  var _filter = _ProductFilter.all;
  final _updatingIds = <int>{};

  int get _storeId {
    final storeId = widget.selectionController.selectedStoreId;
    if (storeId == null) throw StateError('selected store is missing');
    return storeId;
  }

  List<SellerProduct> get _visibleProducts {
    final normalizedQuery = _query.trim().toLowerCase();
    return (_products ?? const []).where((product) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.categoryName.toLowerCase().contains(normalizedQuery);
      final matchesFilter = switch (_filter) {
        _ProductFilter.all => true,
        _ProductFilter.selling => !product.soldOut,
        _ProductFilter.soldOut => product.soldOut,
        _ProductFilter.channelOff =>
          !product.qrWebEnabled || !product.customerAppEnabled,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(message: '스토어 상품을 불러오고 있어요.');
    }
    if (_error != null || _products == null) {
      return PopqErrorView(message: '선택한 스토어의 상품을 불러오지 못했습니다.', onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.sm,
              PopqSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: '상품명 또는 카테고리 검색',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: PopqSpacing.md,
                  vertical: PopqSpacing.sm,
                ),
                children: [
                  _filterChip(_ProductFilter.all, '전체'),
                  _filterChip(_ProductFilter.selling, '판매 중'),
                  _filterChip(_ProductFilter.soldOut, '품절'),
                  _filterChip(_ProductFilter.channelOff, '채널 꺼짐'),
                ],
              ),
            ),
          ),
          if (_visibleProducts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PopqEmptyView(
                icon: Icons.inventory_2_outlined,
                title: '조건에 맞는 상품이 없어요.',
                description: '검색어나 필터를 바꾸거나 아래로 당겨 새로고침해 주세요.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PopqSpacing.md,
                PopqSpacing.sm,
                PopqSpacing.md,
                PopqSpacing.xl,
              ),
              sliver: SliverList.separated(
                itemCount: _visibleProducts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PopqSpacing.md),
                itemBuilder: (context, index) =>
                    _productCard(_visibleProducts[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(_ProductFilter filter, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: PopqSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      ),
    );
  }

  Widget _productCard(SellerProduct product) {
    final isUpdating = _updatingIds.contains(product.productId);
    return Card(
      key: Key('product-${product.productId}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.sm,
            ),
            leading: CircleAvatar(
              backgroundColor: product.soldOut
                  ? const Color(0xFFE7E4EA)
                  : PopqPalette.lime,
              child: Icon(
                product.soldOut
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.local_cafe_outlined,
                color: PopqPalette.ink,
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${product.categoryName} · ${sellerWon(product.basePrice)}',
            ),
            trailing: Chip(
              label: Text(product.soldOut ? '품절' : '판매 중'),
              backgroundColor: product.soldOut
                  ? const Color(0xFFE7E4EA)
                  : const Color(0xFFD7F0E3),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            key: Key('sold-out-${product.productId}'),
            title: const Text('품절 처리'),
            subtitle: const Text('켜면 모든 판매 채널에서 즉시 주문할 수 없습니다.'),
            value: product.soldOut,
            onChanged: isUpdating
                ? null
                : (value) => _update(product, soldOut: value),
          ),
          SwitchListTile(
            key: Key('customer-app-${product.productId}'),
            title: const Text('고객 앱 판매'),
            subtitle: Text(product.customerAppEnabled ? '노출 허용' : '노출 중지'),
            value: product.customerAppEnabled,
            onChanged: isUpdating
                ? null
                : (value) => _update(product, customerAppEnabled: value),
          ),
          SwitchListTile(
            key: Key('qr-web-${product.productId}'),
            title: const Text('QR 웹 판매'),
            subtitle: Text(product.qrWebEnabled ? '노출 허용' : '노출 중지'),
            value: product.qrWebEnabled,
            onChanged: isUpdating
                ? null
                : (value) => _update(product, qrWebEnabled: value),
          ),
          if (isUpdating) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await widget.repository.findAll(_storeId);
      if (!mounted) return;
      setState(() {
        _products = List.of(products);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _update(
    SellerProduct product, {
    bool? soldOut,
    bool? qrWebEnabled,
    bool? customerAppEnabled,
  }) async {
    setState(() => _updatingIds.add(product.productId));
    try {
      final updated = await widget.repository.updateAvailability(
        _storeId,
        product,
        soldOut: soldOut,
        qrWebEnabled: qrWebEnabled,
        customerAppEnabled: customerAppEnabled,
      );
      if (!mounted) return;
      setState(() {
        final index = _products!.indexWhere(
          (candidate) => candidate.productId == updated.productId,
        );
        if (index >= 0) _products![index] = updated;
        _updatingIds.remove(product.productId);
      });
      _showMessage('${updated.name} 판매 상태를 변경했습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingIds.remove(product.productId));
      _showMessage('상품 판매 상태를 변경하지 못했습니다.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
