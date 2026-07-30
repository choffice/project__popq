import 'package:popq_app_core/popq_app_core.dart';

class SellerCategory {
  const SellerCategory({
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.displayOrder,
    this.status = 'ACTIVE',
  });

  factory SellerCategory.fromJson(int storeId, Map<String, Object?> json) {
    return SellerCategory(
      storeId: storeId,
      categoryId: (json['categoryId'] as num).toInt(),
      name: json['name'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
      status: json['status'] as String,
    );
  }

  final int storeId;
  final int categoryId;
  final String name;
  final int displayOrder;
  final String status;
}

class SellerProductOption {
  const SellerProductOption({
    required this.name,
    required this.additionalPrice,
    required this.displayOrder,
  });

  factory SellerProductOption.fromJson(Map<String, Object?> json) {
    return SellerProductOption(
      name: json['name'] as String,
      additionalPrice: (json['additionalPrice'] as num).toInt(),
      displayOrder: (json['displayOrder'] as num).toInt(),
    );
  }

  final String name;
  final int additionalPrice;
  final int displayOrder;

  Map<String, Object?> toJson() => {
    'name': name,
    'additionalPrice': additionalPrice,
    'displayOrder': displayOrder,
  };
}

class SellerProductOptionGroup {
  const SellerProductOptionGroup({
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.required,
    required this.displayOrder,
    required this.options,
  });

  factory SellerProductOptionGroup.fromJson(Map<String, Object?> json) {
    return SellerProductOptionGroup(
      name: json['name'] as String,
      minSelect: (json['minSelect'] as num).toInt(),
      maxSelect: (json['maxSelect'] as num).toInt(),
      required: json['required'] as bool,
      displayOrder: (json['displayOrder'] as num).toInt(),
      options: (json['options'] as List<Object?>)
          .map(
            (item) => SellerProductOption.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  final String name;
  final int minSelect;
  final int maxSelect;
  final bool required;
  final int displayOrder;
  final List<SellerProductOption> options;

  Map<String, Object?> toJson() => {
    'name': name,
    'minSelect': minSelect,
    'maxSelect': maxSelect,
    'required': required,
    'displayOrder': displayOrder,
    'options': options.map((item) => item.toJson()).toList(),
  };
}

class SellerProductDetail {
  const SellerProductDetail({
    required this.product,
    required this.optionGroups,
  });

  final SellerProduct product;
  final List<SellerProductOptionGroup> optionGroups;
}

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
    int? categoryId,
    String? categoryName,
    String? name,
    String? description,
    String? imageUrl,
    int? basePrice,
    bool? soldOut,
    bool? availableForQr,
    bool? availableForCustomerApp,
    bool? qrWebEnabled,
    bool? customerAppEnabled,
  }) {
    return SellerProduct(
      productId: productId,
      storeId: storeId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
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
  Future<List<SellerCategory>> findCategories(int storeId);

  Future<SellerCategory> createCategory(
    int storeId, {
    required String name,
    required int displayOrder,
  });

  Future<SellerCategory> updateCategory(
    int storeId,
    int categoryId, {
    required String name,
    required int displayOrder,
  });

  Future<List<SellerProduct>> findAll(int storeId);

  Future<SellerProduct> create(
    int storeId, {
    required int categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required int basePrice,
  });

  Future<SellerProduct> update(
    int storeId,
    SellerProduct product, {
    required int categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required int basePrice,
  });

  Future<SellerProductDetail> findOne(int storeId, SellerProduct product);

  Future<SellerProductDetail> replaceOptions(
    int storeId,
    SellerProduct product,
    List<SellerProductOptionGroup> groups,
  );

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

  String _categoryPath(int storeId) =>
      '/api/v1/seller/stores/$storeId/categories';

  @override
  Future<List<SellerCategory>> findCategories(int storeId) {
    return _apiClient.get(
      _categoryPath(storeId),
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => SellerCategory.fromJson(
              storeId,
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SellerCategory> createCategory(
    int storeId, {
    required String name,
    required int displayOrder,
  }) {
    return _apiClient.post(
      _categoryPath(storeId),
      body: {'name': name, 'displayOrder': displayOrder},
      decode: (value) => SellerCategory.fromJson(
        storeId,
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerCategory> updateCategory(
    int storeId,
    int categoryId, {
    required String name,
    required int displayOrder,
  }) {
    return _apiClient.patch(
      '${_categoryPath(storeId)}/$categoryId',
      body: {'name': name, 'displayOrder': displayOrder},
      decode: (value) => SellerCategory.fromJson(
        storeId,
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

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
  Future<SellerProduct> create(
    int storeId, {
    required int categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required int basePrice,
  }) {
    return _apiClient.post(
      _basePath(storeId),
      body: {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'basePrice': basePrice,
      },
      decode: (value) => _decodeDetailProduct(storeId, value),
    );
  }

  @override
  Future<SellerProduct> update(
    int storeId,
    SellerProduct product, {
    required int categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required int basePrice,
  }) {
    if (product.storeId != storeId) {
      throw StateError('product does not belong to selected store');
    }
    return _apiClient.patch(
      '${_basePath(storeId)}/${product.productId}',
      body: {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'basePrice': basePrice,
      },
      decode: (value) => _decodeDetailProduct(storeId, value),
    );
  }

  SellerProduct _decodeDetailProduct(int storeId, Object? value) {
    final detail = Map<String, Object?>.from(value as Map);
    return SellerProduct.fromJson(
      storeId,
      Map<String, Object?>.from(detail['product'] as Map),
    );
  }

  SellerProductDetail _decodeDetail(int storeId, Object? value) {
    final detail = Map<String, Object?>.from(value as Map);
    return SellerProductDetail(
      product: SellerProduct.fromJson(
        storeId,
        Map<String, Object?>.from(detail['product'] as Map),
      ),
      optionGroups: (detail['optionGroups'] as List<Object?>)
          .map(
            (item) => SellerProductOptionGroup.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SellerProductDetail> findOne(
    int storeId,
    SellerProduct product,
  ) {
    if (product.storeId != storeId) {
      throw StateError('product does not belong to selected store');
    }
    return _apiClient.get(
      '${_basePath(storeId)}/${product.productId}',
      decode: (value) => _decodeDetail(storeId, value),
    );
  }

  @override
  Future<SellerProductDetail> replaceOptions(
    int storeId,
    SellerProduct product,
    List<SellerProductOptionGroup> groups,
  ) {
    if (product.storeId != storeId) {
      throw StateError('product does not belong to selected store');
    }
    return _apiClient.put(
      '${_basePath(storeId)}/${product.productId}/options',
      body: {'groups': groups.map((item) => item.toJson()).toList()},
      decode: (value) => _decodeDetail(storeId, value),
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
  MemorySellerProductRepository({
    List<SellerProduct> products = const [],
    List<SellerCategory> categories = const [],
    Map<int, List<SellerProductOptionGroup>> optionGroups = const {},
  }) : _products = List.of(products),
       _categories = List.of(categories),
       _optionGroups = optionGroups.map(
         (key, value) => MapEntry(key, List.of(value)),
       ) {
    for (final product in products) {
      if (_categories.every(
        (item) =>
            item.storeId != product.storeId ||
            item.categoryId != product.categoryId,
      )) {
        _categories.add(
          SellerCategory(
            storeId: product.storeId,
            categoryId: product.categoryId,
            name: product.categoryName,
            displayOrder: _categories
                .where((item) => item.storeId == product.storeId)
                .length,
          ),
        );
      }
    }
  }

  final List<SellerProduct> _products;
  final List<SellerCategory> _categories;
  final Map<int, List<SellerProductOptionGroup>> _optionGroups;

  @override
  Future<List<SellerCategory>> findCategories(int storeId) async {
    final result = <SellerCategory>[
      ..._categories.where((item) => item.storeId == storeId),
    ];
    result.sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
    return List.unmodifiable(result);
  }

  @override
  Future<SellerCategory> createCategory(
    int storeId, {
    required String name,
    required int displayOrder,
  }) async {
    final nextId = _categories.fold<int>(
          0,
          (value, item) => item.categoryId > value ? item.categoryId : value,
        ) +
        1;
    final created = SellerCategory(
      storeId: storeId,
      categoryId: nextId,
      name: name,
      displayOrder: displayOrder,
    );
    _categories.add(created);
    return created;
  }

  @override
  Future<SellerCategory> updateCategory(
    int storeId,
    int categoryId, {
    required String name,
    required int displayOrder,
  }) async {
    final index = _categories.indexWhere(
      (item) => item.storeId == storeId && item.categoryId == categoryId,
    );
    if (index < 0) throw StateError('category not found in selected store');
    final updated = SellerCategory(
      storeId: storeId,
      categoryId: categoryId,
      name: name,
      displayOrder: displayOrder,
      status: _categories[index].status,
    );
    _categories[index] = updated;
    for (var i = 0; i < _products.length; i++) {
      final product = _products[i];
      if (product.storeId == storeId && product.categoryId == categoryId) {
        _products[i] = product.copyWith(categoryName: name);
      }
    }
    return updated;
  }

  @override
  Future<List<SellerProduct>> findAll(int storeId) async {
    return List.unmodifiable(
      _products.where((product) => product.storeId == storeId),
    );
  }

  @override
  Future<SellerProduct> create(
    int storeId, {
    required int categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required int basePrice,
  }) async {
    final category = (await findCategories(storeId)).firstWhere(
      (item) => item.categoryId == categoryId,
    );
    final nextId = _products.fold<int>(
          0,
          (value, item) => item.productId > value ? item.productId : value,
        ) +
        1;
    final created = SellerProduct(
      productId: nextId,
      storeId: storeId,
      categoryId: categoryId,
      categoryName: category.name,
      name: name,
      description: description,
      imageUrl: imageUrl,
      basePrice: basePrice,
      status: 'ACTIVE',
      soldOut: false,
      availableForQr: true,
      availableForCustomerApp: true,
      qrWebEnabled: true,
      customerAppEnabled: true,
    );
    _products.add(created);
    return created;
  }

  @override
  Future<SellerProduct> update(
    int storeId,
    SellerProduct product, {
    required int categoryId,
    required String name,
    String? description,
    String? imageUrl,
    required int basePrice,
  }) async {
    final index = _products.indexWhere(
      (item) => item.storeId == storeId && item.productId == product.productId,
    );
    if (index < 0 || product.storeId != storeId) {
      throw StateError('product not found in selected store');
    }
    final category = (await findCategories(storeId)).firstWhere(
      (item) => item.categoryId == categoryId,
    );
    final updated = SellerProduct(
      productId: product.productId,
      storeId: storeId,
      categoryId: categoryId,
      categoryName: category.name,
      name: name,
      description: description,
      imageUrl: imageUrl,
      basePrice: basePrice,
      status: product.status,
      soldOut: product.soldOut,
      availableForQr: product.availableForQr,
      availableForCustomerApp: product.availableForCustomerApp,
      salesStartAt: product.salesStartAt,
      salesEndAt: product.salesEndAt,
      qrWebEnabled: product.qrWebEnabled,
      customerAppEnabled: product.customerAppEnabled,
    );
    _products[index] = updated;
    return updated;
  }

  @override
  Future<SellerProductDetail> findOne(
    int storeId,
    SellerProduct product,
  ) async {
    final stored = _products.where(
      (item) => item.storeId == storeId && item.productId == product.productId,
    );
    if (stored.isEmpty || product.storeId != storeId) {
      throw StateError('product not found in selected store');
    }
    return SellerProductDetail(
      product: stored.single,
      optionGroups: List.unmodifiable(
        _optionGroups[product.productId] ?? const [],
      ),
    );
  }

  @override
  Future<SellerProductDetail> replaceOptions(
    int storeId,
    SellerProduct product,
    List<SellerProductOptionGroup> groups,
  ) async {
    final detail = await findOne(storeId, product);
    _optionGroups[product.productId] = List.of(groups);
    return SellerProductDetail(
      product: detail.product,
      optionGroups: List.unmodifiable(groups),
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
