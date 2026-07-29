import 'package:flutter/foundation.dart';

import '../catalog/catalog_repository.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.options,
    required this.quantity,
  });

  final CatalogProduct product;
  final List<ProductOption> options;
  final int quantity;

  int get unitPrice {
    return product.basePrice +
        options.fold(0, (sum, option) => sum + option.additionalPrice);
  }

  int get totalPrice => unitPrice * quantity;

  String get identity {
    final optionKey = options.map((option) => option.optionId).toList()..sort();
    return '${product.productId}:${optionKey.join(',')}';
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      options: options,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartStoreConflict implements Exception {
  const CartStoreConflict();
}

class CartController extends ChangeNotifier {
  int? storeId;
  final List<CartItem> items = [];

  bool get isEmpty => items.isEmpty;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get totalAmount {
    return items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  void add({
    required int targetStoreId,
    required CatalogProduct product,
    required List<ProductOption> options,
    required int quantity,
  }) {
    if (storeId != null && storeId != targetStoreId && items.isNotEmpty) {
      throw const CartStoreConflict();
    }
    storeId = targetStoreId;
    final incoming = CartItem(
      product: product,
      options: List.unmodifiable(options),
      quantity: quantity,
    );
    final index = items.indexWhere(
      (item) => item.identity == incoming.identity,
    );
    if (index < 0) {
      items.add(incoming);
    } else {
      items[index] = items[index].copyWith(
        quantity: items[index].quantity + quantity,
      );
    }
    notifyListeners();
  }

  void changeQuantity(CartItem item, int quantity) {
    final index = items.indexOf(item);
    if (index < 0) return;
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = item.copyWith(quantity: quantity.clamp(1, 99));
    }
    if (items.isEmpty) storeId = null;
    notifyListeners();
  }

  void clear() {
    storeId = null;
    items.clear();
    notifyListeners();
  }

  void replaceWith({
    required int targetStoreId,
    required CatalogProduct product,
    required List<ProductOption> options,
    required int quantity,
  }) {
    clear();
    add(
      targetStoreId: targetStoreId,
      product: product,
      options: options,
      quantity: quantity,
    );
  }
}
