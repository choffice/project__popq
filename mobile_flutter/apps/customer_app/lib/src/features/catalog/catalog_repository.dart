import 'package:popq_app_core/popq_app_core.dart';

class CatalogProduct {
  const CatalogProduct({
    required this.productId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.basePrice,
    required this.soldOut,
    required this.availableForCustomerApp,
    this.description,
    this.imageUrl,
    this.optionGroups = const [],
  });

  factory CatalogProduct.fromSummary(Map<String, Object?> json) {
    return CatalogProduct(
      productId: (json['productId'] as num).toInt(),
      categoryId: (json['categoryId'] as num).toInt(),
      categoryName: json['categoryName'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      basePrice: (json['basePrice'] as num).toInt(),
      soldOut: json['soldOut'] as bool? ?? false,
      availableForCustomerApp:
          json['availableForCustomerApp'] as bool? ?? false,
    );
  }

  factory CatalogProduct.fromDetail(Map<String, Object?> json) {
    final product = CatalogProduct.fromSummary(
      Map<String, Object?>.from(json['product'] as Map),
    );
    return CatalogProduct(
      productId: product.productId,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      name: product.name,
      description: product.description,
      imageUrl: product.imageUrl,
      basePrice: product.basePrice,
      soldOut: product.soldOut,
      availableForCustomerApp: product.availableForCustomerApp,
      optionGroups: (json['optionGroups'] as List<Object?>? ?? const [])
          .map(
            (value) => ProductOptionGroup.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList(),
    );
  }

  final int productId;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final String? imageUrl;
  final int basePrice;
  final bool soldOut;
  final bool availableForCustomerApp;
  final List<ProductOptionGroup> optionGroups;
}

class ProductOptionGroup {
  const ProductOptionGroup({
    required this.optionGroupId,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.required,
    required this.options,
  });

  factory ProductOptionGroup.fromJson(Map<String, Object?> json) {
    return ProductOptionGroup(
      optionGroupId: (json['optionGroupId'] as num).toInt(),
      name: json['name'] as String,
      minSelect: (json['minSelect'] as num).toInt(),
      maxSelect: (json['maxSelect'] as num).toInt(),
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<Object?>? ?? const [])
          .map(
            (value) =>
                ProductOption.fromJson(Map<String, Object?>.from(value as Map)),
          )
          .toList(),
    );
  }

  final int optionGroupId;
  final String name;
  final int minSelect;
  final int maxSelect;
  final bool required;
  final List<ProductOption> options;
}

class ProductOption {
  const ProductOption({
    required this.optionId,
    required this.name,
    required this.additionalPrice,
  });

  factory ProductOption.fromJson(Map<String, Object?> json) {
    return ProductOption(
      optionId: (json['optionId'] as num).toInt(),
      name: json['name'] as String,
      additionalPrice: (json['additionalPrice'] as num).toInt(),
    );
  }

  final int optionId;
  final String name;
  final int additionalPrice;
}

abstract interface class CatalogRepository {
  Future<List<CatalogProduct>> findProducts(int storeId);

  Future<CatalogProduct> findProduct(int storeId, int productId);
}

class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<List<CatalogProduct>> findProducts(int storeId) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId/products',
      decode: (value) {
        return (value as List<Object?>)
            .map(
              (item) => CatalogProduct.fromSummary(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<CatalogProduct> findProduct(int storeId, int productId) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId/products/$productId',
      decode: (value) =>
          CatalogProduct.fromDetail(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemoryCatalogRepository implements CatalogRepository {
  MemoryCatalogRepository({List<CatalogProduct>? products})
    : _products = products ?? sampleProducts;

  static const sampleProducts = [
    CatalogProduct(
      productId: 101,
      categoryId: 10,
      categoryName: '커피',
      name: '아메리카노',
      description: '고소하고 깔끔한 데일리 커피',
      basePrice: 5000,
      soldOut: false,
      availableForCustomerApp: true,
      optionGroups: [
        ProductOptionGroup(
          optionGroupId: 1001,
          name: '온도',
          minSelect: 1,
          maxSelect: 1,
          required: true,
          options: [
            ProductOption(optionId: 1, name: '아이스', additionalPrice: 500),
            ProductOption(optionId: 2, name: '핫', additionalPrice: 0),
          ],
        ),
      ],
    ),
    CatalogProduct(
      productId: 102,
      categoryId: 20,
      categoryName: '디저트',
      name: '레몬 케이크',
      basePrice: 6500,
      soldOut: false,
      availableForCustomerApp: true,
    ),
  ];

  final List<CatalogProduct> _products;

  @override
  Future<CatalogProduct> findProduct(int storeId, int productId) async {
    return _products.firstWhere((product) => product.productId == productId);
  }

  @override
  Future<List<CatalogProduct>> findProducts(int storeId) async => _products;
}
