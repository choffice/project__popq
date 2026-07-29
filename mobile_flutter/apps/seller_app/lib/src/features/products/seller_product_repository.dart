import 'package:popq_app_core/popq_app_core.dart';

class SellerProduct {
  const SellerProduct({
    required this.productId,
    required this.storeId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.basePrice,
    required this.status,
    required this.soldOut,
    required this.availableForQr,
    required this.availableForCustomerApp,
    required this.qrWebEnabled,
    required this.customerAppEnabled,
    this.description,
    this.imageUrl,
    this.salesStartAt,
    this.salesEndAt,
  });

  factory SellerProduct.fromJson(int storeId, Map<String, Object?> json) {
    return SellerProduct(
      productId: (json['productId'] as num).toInt(),
      storeId: storeId,
      categoryId: (json['categoryId'] as num).toInt(),
      categoryName: json['categoryName'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      basePrice: (json['basePrice'] as num).toInt(),
      status: json['status'] as String,
      soldOut: json['soldOut'] as bool,
      availableForQr: json['availableForQr'] as bool,
      availableForCustomerApp: json['availableForCustomerApp'] as bool,
      salesStartAt: json['salesStartAt'] as String?,
      salesEndAt: json['salesEndAt'] as String?,
      qrWebEnabled: json['qrWebEnabled'] as bool,
      customerAppEnabled: json['customerAppEnabled'] as bool,
    );
  }

  final int productId;
  final int storeId;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final String? imageUrl;
  final int basePrice;
  final String status;
  final bool soldOut;
  final bool availableForQr;
  final bool availableForCustomerApp;
  final String? salesStartAt;
  final String? salesEndAt;
  final bool qrWebEnabled;
  final bool customerAppEnabled;

  SellerProduct copyWith({
    bool? soldOut,
    bool? availableForQr,
    bool? availableForCustomerApp,
    bool? qrWebEnabled,
    bool? customerAppEnabled,
  }) {
    return SellerProduct(
      productId: productId,
      storeId: storeId,
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      description: description,
      imageUrl: imageUrl,
      basePrice: basePrice,
      status: status,
      soldOut: soldOut ?? this.soldOut,
      availableForQr: availableForQr ?? this.availableForQr,
      availableForCustomerApp:
          availableForCustomerApp ?? this.availableForCustomerApp,
      salesStartAt: salesStartAt,
      salesEndAt: salesEndAt,
      qrWebEnabled: qrWebEnabled ?? this.qrWebEnabled,
      customerAppEnabled: customerAppEnabled ?? this.customerAppEnabled,
    );
  }
}

abstract interface class SellerProductRepository {
  Future<List<SellerProduct>> findAll(int storeId);

  Future<SellerProduct> updateAvailability(
    int storeId,
    SellerProduct product, {
    bool? soldOut,
    bool? qrWebEnabled,
    bool? customerAppEnabled,
  });
}

class ApiSellerProductRepository implements SellerProductRepository {
  ApiSellerProductRepository(this._apiClient);

  final PopqApiClient _apiClient;

  String _basePath(int storeId) => '/api/v1/seller/stores/$storeId/products';

  @override
  Future<List<SellerProduct>> findAll(int storeId) {
    return _apiClient.get(
      _basePath(storeId),
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => SellerProduct.fromJson(
              storeId,
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SellerProduct> updateAvailability(
    int storeId,
    SellerProduct product, {
    bool? soldOut,
    bool? qrWebEnabled,
    bool? customerAppEnabled,
  }) {
    if (product.storeId != storeId) {
      throw StateError('product does not belong to selected store');
    }
    return _apiClient.patch(
      '${_basePath(storeId)}/${product.productId}/availability',
      body: {
        'soldOut': soldOut ?? product.soldOut,
        'salesStartAt': product.salesStartAt,
        'salesEndAt': product.salesEndAt,
        'qrWebEnabled': qrWebEnabled ?? product.qrWebEnabled,
        'customerAppEnabled': customerAppEnabled ?? product.customerAppEnabled,
      },
      decode: (value) {
        final detail = Map<String, Object?>.from(value as Map);
        return SellerProduct.fromJson(
          storeId,
          Map<String, Object?>.from(detail['product'] as Map),
        );
      },
    );
  }
}

class MemorySellerProductRepository implements SellerProductRepository {
  MemorySellerProductRepository({List<SellerProduct> products = const []})
    : _products = List.of(products);

  final List<SellerProduct> _products;

  @override
  Future<List<SellerProduct>> findAll(int storeId) async {
    return List.unmodifiable(
      _products.where((product) => product.storeId == storeId),
    );
  }

  @override
  Future<SellerProduct> updateAvailability(
    int storeId,
    SellerProduct product, {
    bool? soldOut,
    bool? qrWebEnabled,
    bool? customerAppEnabled,
  }) async {
    final index = _products.indexWhere(
      (candidate) =>
          candidate.storeId == storeId &&
          candidate.productId == product.productId,
    );
    if (index < 0 || product.storeId != storeId) {
      throw StateError('product not found in selected store');
    }
    final nextSoldOut = soldOut ?? product.soldOut;
    final nextQrEnabled = qrWebEnabled ?? product.qrWebEnabled;
    final nextCustomerEnabled =
        customerAppEnabled ?? product.customerAppEnabled;
    final updated = product.copyWith(
      soldOut: nextSoldOut,
      qrWebEnabled: nextQrEnabled,
      customerAppEnabled: nextCustomerEnabled,
      availableForQr: !nextSoldOut && nextQrEnabled,
      availableForCustomerApp: !nextSoldOut && nextCustomerEnabled,
    );
    _products[index] = updated;
    return updated;
  }
}
