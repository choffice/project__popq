import 'dart:typed_data';

import 'package:popq_app_core/popq_app_core.dart';

class SellerCategory {
  const SellerCategory({
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.displayOrder,
    this.status = 'ACTIVE',
  });

  factory SellerCategory.fromJson(
      int storeId,
      Map<String, Object?> json,
      ) {
    return SellerCategory(
      storeId: storeId,
      categoryId:
      (json['categoryId'] as num).toInt(),
      name: json['name'] as String,
      displayOrder:
      (json['displayOrder'] as num).toInt(),
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

  factory SellerProductOption.fromJson(
      Map<String, Object?> json,
      ) {
    return SellerProductOption(
      name: json['name'] as String,
      additionalPrice:
      (json['additionalPrice'] as num).toInt(),
      displayOrder:
      (json['displayOrder'] as num).toInt(),
    );
  }

  final String name;
  final int additionalPrice;
  final int displayOrder;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'additionalPrice': additionalPrice,
      'displayOrder': displayOrder,
    };
  }
}

class SellerProductOptionGroup {
  const SellerProductOptionGroup({
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.required,
    required this.displayOrder,
    required this.options,
    this.optionGroupId,
    this.templateId,
    this.appliedTemplateVersion,
  });

  factory SellerProductOptionGroup.fromJson(
      Map<String, Object?> json,
      ) {
    return SellerProductOptionGroup(
      optionGroupId: (json['optionGroupId'] as num?)?.toInt(),
      name: json['name'] as String,
      minSelect:
      (json['minSelect'] as num).toInt(),
      maxSelect:
      (json['maxSelect'] as num).toInt(),
      required: json['required'] as bool,
      displayOrder:
      (json['displayOrder'] as num).toInt(),
      templateId: (json['templateId'] as num?)?.toInt(),
      appliedTemplateVersion:
      (json['appliedTemplateVersion'] as num?)?.toInt(),
      options: (json['options'] as List<Object?>)
          .map(
            (Object? item) =>
            SellerProductOption.fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
            ),
      )
          .toList(),
    );
  }

  final String name;
  final int? optionGroupId;
  final int minSelect;
  final int maxSelect;
  final bool required;
  final int displayOrder;
  final List<SellerProductOption> options;
  final int? templateId;
  final int? appliedTemplateVersion;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'minSelect': minSelect,
      'maxSelect': maxSelect,
      'required': required,
      'displayOrder': displayOrder,
      'templateId': templateId,
      'appliedTemplateVersion': appliedTemplateVersion,
      'options': options
          .map(
            (SellerProductOption item) =>
            item.toJson(),
      )
          .toList(),
    };
  }
}

class SellerStoreOptionTemplate {
  const SellerStoreOptionTemplate({
    required this.templateId,
    required this.storeId,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.required,
    required this.version,
    required this.options,
  });

  factory SellerStoreOptionTemplate.fromJson(Map<String, Object?> json) {
    return SellerStoreOptionTemplate(
      templateId: (json['templateId'] as num).toInt(),
      storeId: (json['storeId'] as num).toInt(),
      name: json['name'] as String,
      minSelect: (json['minSelect'] as num).toInt(),
      maxSelect: (json['maxSelect'] as num).toInt(),
      required: json['required'] as bool,
      version: (json['version'] as num).toInt(),
      options: (json['options'] as List<Object?>)
          .map((item) => SellerProductOption.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(),
    );
  }

  final int templateId;
  final int storeId;
  final String name;
  final int minSelect;
  final int maxSelect;
  final bool required;
  final int version;
  final List<SellerProductOption> options;
}

class SellerOptionTemplateUsage {
  const SellerOptionTemplateUsage({
    required this.templateId,
    required this.totalCount,
    required this.products,
  });

  factory SellerOptionTemplateUsage.fromJson(Map<String, Object?> json) {
    return SellerOptionTemplateUsage(
      templateId: (json['templateId'] as num).toInt(),
      totalCount: (json['totalCount'] as num).toInt(),
      products: (json['products'] as List<Object?>)
          .map((item) {
            final value = Map<String, Object?>.from(item as Map);
            return SellerOptionTemplateProduct(
              productId: (value['productId'] as num).toInt(),
              productName: value['productName'] as String,
            );
          })
          .toList(),
    );
  }

  final int templateId;
  final int totalCount;
  final List<SellerOptionTemplateProduct> products;
}

class SellerOptionTemplateProduct {
  const SellerOptionTemplateProduct({
    required this.productId,
    required this.productName,
  });

  final int productId;
  final String productName;
}

class SellerProductDetail {
  const SellerProductDetail({
    required this.product,
    required this.optionGroups,
  });

  final SellerProduct product;
  final List<SellerProductOptionGroup>
  optionGroups;
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

  factory SellerProduct.fromJson(
      int storeId,
      Map<String, Object?> json,
      ) {
    return SellerProduct(
      productId:
      (json['productId'] as num).toInt(),
      storeId: storeId,
      categoryId:
      (json['categoryId'] as num).toInt(),
      categoryName:
      json['categoryName'] as String,
      name: json['name'] as String,
      description:
      json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      basePrice:
      (json['basePrice'] as num).toInt(),
      status: json['status'] as String,
      soldOut: json['soldOut'] as bool,
      availableForQr:
      json['availableForQr'] as bool,
      availableForCustomerApp:
      json['availableForCustomerApp']
      as bool,
      salesStartAt:
      json['salesStartAt'] as String?,
      salesEndAt:
      json['salesEndAt'] as String?,
      qrWebEnabled:
      json['qrWebEnabled'] as bool,
      customerAppEnabled:
      json['customerAppEnabled'] as bool,
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
      categoryId:
      categoryId ?? this.categoryId,
      categoryName:
      categoryName ?? this.categoryName,
      name: name ?? this.name,
      description:
      description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
      status: status,
      soldOut: soldOut ?? this.soldOut,
      availableForQr:
      availableForQr ?? this.availableForQr,
      availableForCustomerApp:
      availableForCustomerApp ??
          this.availableForCustomerApp,
      salesStartAt: salesStartAt,
      salesEndAt: salesEndAt,
      qrWebEnabled:
      qrWebEnabled ?? this.qrWebEnabled,
      customerAppEnabled:
      customerAppEnabled ??
          this.customerAppEnabled,
    );
  }
}

abstract interface class
SellerProductRepository {
  Future<List<SellerCategory>> findCategories(
      int storeId,
      );

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

  Future<void> deleteCategory(
      int storeId,
      int categoryId,
      );

  Future<String> uploadProductImage(
      String filePath,
      );

  Future<String> uploadProductImageBytes(
    Uint8List bytes, {
    required String fileName,
  });

  Future<List<SellerProduct>> findAll(
      int storeId,
      );

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

  Future<void> deleteProduct(
      int storeId,
      SellerProduct product,
      );

  Future<SellerProductDetail> findOne(
      int storeId,
      SellerProduct product,
      );

  Future<SellerProductDetail> replaceOptions(
      int storeId,
      SellerProduct product,
      List<SellerProductOptionGroup> groups,
      );

  Future<List<SellerStoreOptionTemplate>> findOptionTemplates(int storeId);

  Future<SellerStoreOptionTemplate> createOptionTemplate(
    int storeId,
    SellerProductOptionGroup group,
  );

  Future<SellerOptionTemplateUsage> findOptionTemplateUsage(
    int storeId,
    int templateId,
  );

  Future<SellerStoreOptionTemplate> applyOptionTemplateToAll(
    int storeId,
    SellerProduct product,
    SellerProductOptionGroup group,
  );

  Future<void> deleteOptionTemplate(int storeId, int templateId);

  Future<SellerProduct> updateAvailability(
      int storeId,
      SellerProduct product, {
        bool? soldOut,
        bool? qrWebEnabled,
        bool? customerAppEnabled,
      });
}

class ApiSellerProductRepository
    implements SellerProductRepository {
  ApiSellerProductRepository(
      this._apiClient,
      );

  final PopqApiClient _apiClient;

  String _basePath(int storeId) {
    return '/api/v1/seller/stores/'
        '$storeId/products';
  }

  String _categoryPath(int storeId) {
    return '/api/v1/seller/stores/'
        '$storeId/categories';
  }

  @override
  Future<String> uploadProductImage(
      String filePath,
      ) {
    return _apiClient.postMultipartFile<String>(
      '/api/v1/seller/store-images',
      fieldName: 'file',
      filePath: filePath,
      decode: (Object? value) {
        final Map<String, Object?> json =
        Map<String, Object?>.from(
          value as Map,
        );

        final Object? imageUrl =
        json['imageUrl'];

        if (imageUrl is! String ||
            imageUrl.trim().isEmpty) {
          throw const InvalidResponseFailure(
            '업로드된 이미지 URL이 없습니다.',
          );
        }

        return imageUrl;
      },
    );
  }

  @override
  Future<String> uploadProductImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    return _apiClient.postMultipartBytes<String>(
      '/api/v1/seller/store-images',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
      decode: (Object? value) {
        final Map<String, Object?> json =
            Map<String, Object?>.from(value as Map);
        final Object? imageUrl = json['imageUrl'];
        if (imageUrl is! String || imageUrl.trim().isEmpty) {
          throw const InvalidResponseFailure('업로드된 이미지 URL이 없습니다.');
        }
        return imageUrl;
      },
    );
  }

  @override
  Future<List<SellerCategory>>
  findCategories(
      int storeId,
      ) {
    return _apiClient.get(
      _categoryPath(storeId),
      decode: (Object? value) {
        return (value as List<Object?>)
            .map(
              (Object? item) =>
              SellerCategory.fromJson(
                storeId,
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
        )
            .toList();
      },
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
      body: {
        'name': name,
        'displayOrder': displayOrder,
      },
      decode: (Object? value) {
        return SellerCategory.fromJson(
          storeId,
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
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
      '${_categoryPath(storeId)}/'
          '$categoryId',
      body: {
        'name': name,
        'displayOrder': displayOrder,
      },
      decode: (Object? value) {
        return SellerCategory.fromJson(
          storeId,
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<void> deleteCategory(
      int storeId,
      int categoryId,
      ) async {
    final bool deleted =
    await _apiClient.delete(
      '${_categoryPath(storeId)}/'
          '$categoryId',
      decode: (Object? value) {
        return value as bool;
      },
    );

    if (!deleted) {
      throw StateError(
        'category delete failed',
      );
    }
  }

  @override
  Future<List<SellerProduct>> findAll(
      int storeId,
      ) {
    return _apiClient.get(
      _basePath(storeId),
      decode: (Object? value) {
        return (value as List<Object?>)
            .map(
              (Object? item) =>
              SellerProduct.fromJson(
                storeId,
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
        )
            .toList();
      },
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
      decode: (Object? value) {
        return _decodeDetailProduct(
          storeId,
          value,
        );
      },
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
    _validateProductStore(
      storeId,
      product,
    );

    return _apiClient.patch(
      '${_basePath(storeId)}/'
          '${product.productId}',
      body: {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'basePrice': basePrice,
      },
      decode: (Object? value) {
        return _decodeDetailProduct(
          storeId,
          value,
        );
      },
    );
  }

  @override
  Future<void> deleteProduct(
      int storeId,
      SellerProduct product,
      ) async {
    _validateProductStore(
      storeId,
      product,
    );

    final bool deleted =
    await _apiClient.delete(
      '${_basePath(storeId)}/'
          '${product.productId}',
      decode: (Object? value) {
        return value as bool;
      },
    );

    if (!deleted) {
      throw StateError(
        'product delete failed',
      );
    }
  }

  SellerProduct _decodeDetailProduct(
      int storeId,
      Object? value,
      ) {
    final Map<String, Object?> detail =
    Map<String, Object?>.from(
      value as Map,
    );

    return SellerProduct.fromJson(
      storeId,
      Map<String, Object?>.from(
        detail['product'] as Map,
      ),
    );
  }

  SellerProductDetail _decodeDetail(
      int storeId,
      Object? value,
      ) {
    final Map<String, Object?> detail =
    Map<String, Object?>.from(
      value as Map,
    );

    return SellerProductDetail(
      product: SellerProduct.fromJson(
        storeId,
        Map<String, Object?>.from(
          detail['product'] as Map,
        ),
      ),
      optionGroups:
      (detail['optionGroups']
      as List<Object?>)
          .map(
            (Object? item) =>
            SellerProductOptionGroup
                .fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
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
    _validateProductStore(
      storeId,
      product,
    );

    return _apiClient.get(
      '${_basePath(storeId)}/'
          '${product.productId}',
      decode: (Object? value) {
        return _decodeDetail(
          storeId,
          value,
        );
      },
    );
  }

  @override
  Future<SellerProductDetail>
  replaceOptions(
      int storeId,
      SellerProduct product,
      List<SellerProductOptionGroup> groups,
      ) {
    _validateProductStore(
      storeId,
      product,
    );

    return _apiClient.put(
      '${_basePath(storeId)}/'
          '${product.productId}/options',
      body: {
        'groups': groups
            .map(
              (
              SellerProductOptionGroup item,
              ) =>
              item.toJson(),
        )
            .toList(),
      },
      decode: (Object? value) {
        return _decodeDetail(
          storeId,
          value,
        );
      },
    );
  }

  @override
  Future<List<SellerStoreOptionTemplate>> findOptionTemplates(int storeId) {
    return _apiClient.get(
      '/api/v1/seller/stores/$storeId/option-group-templates',
      decode: (value) => (value as List<Object?>)
          .map((item) => SellerStoreOptionTemplate.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(),
    );
  }

  @override
  Future<SellerStoreOptionTemplate> createOptionTemplate(
    int storeId,
    SellerProductOptionGroup group,
  ) {
    return _apiClient.post(
      '/api/v1/seller/stores/$storeId/option-group-templates',
      body: _templateBody(group),
      decode: (value) => SellerStoreOptionTemplate.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerOptionTemplateUsage> findOptionTemplateUsage(
    int storeId,
    int templateId,
  ) {
    return _apiClient.get(
      '/api/v1/seller/stores/$storeId/'
      'option-group-templates/$templateId/products',
      decode: (value) => SellerOptionTemplateUsage.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerStoreOptionTemplate> applyOptionTemplateToAll(
    int storeId,
    SellerProduct product,
    SellerProductOptionGroup group,
  ) {
    _validateProductStore(storeId, product);
    final templateId = group.templateId;
    final optionGroupId = group.optionGroupId;
    if (templateId == null || optionGroupId == null) {
      throw StateError('saved template option group is required');
    }
    return _apiClient.post(
      '/api/v1/seller/stores/$storeId/'
      'option-group-templates/$templateId/apply',
      body: {
        'sourceProductId': product.productId,
        'sourceOptionGroupId': optionGroupId,
        ..._templateBody(group),
      },
      decode: (value) => SellerStoreOptionTemplate.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<void> deleteOptionTemplate(int storeId, int templateId) async {
    await _apiClient.delete<bool>(
      '/api/v1/seller/stores/$storeId/option-group-templates/$templateId',
      decode: (value) => value as bool,
    );
  }

  Map<String, Object?> _templateBody(SellerProductOptionGroup group) {
    return {
      'name': group.name,
      'minSelect': group.minSelect,
      'maxSelect': group.maxSelect,
      'required': group.required,
      'options': group.options.map((option) => option.toJson()).toList(),
    };
  }

  @override
  Future<SellerProduct>
  updateAvailability(
      int storeId,
      SellerProduct product, {
        bool? soldOut,
        bool? qrWebEnabled,
        bool? customerAppEnabled,
      }) {
    _validateProductStore(
      storeId,
      product,
    );

    return _apiClient.patch(
      '${_basePath(storeId)}/'
          '${product.productId}/availability',
      body: {
        'soldOut':
        soldOut ?? product.soldOut,
        'salesStartAt':
        product.salesStartAt,
        'salesEndAt': product.salesEndAt,
        'qrWebEnabled':
        qrWebEnabled ??
            product.qrWebEnabled,
        'customerAppEnabled':
        customerAppEnabled ??
            product.customerAppEnabled,
      },
      decode: (Object? value) {
        final Map<String, Object?> detail =
        Map<String, Object?>.from(
          value as Map,
        );

        return SellerProduct.fromJson(
          storeId,
          Map<String, Object?>.from(
            detail['product'] as Map,
          ),
        );
      },
    );
  }

  void _validateProductStore(
      int storeId,
      SellerProduct product,
      ) {
    if (product.storeId != storeId) {
      throw StateError(
        'product does not belong to '
            'selected store',
      );
    }
  }
}

class MemorySellerProductRepository
    implements SellerProductRepository {
  MemorySellerProductRepository({
    List<SellerProduct> products =
    const <SellerProduct>[],
    List<SellerCategory> categories =
    const <SellerCategory>[],
    Map<int, List<SellerProductOptionGroup>>
    optionGroups =
    const <
        int,
        List<
            SellerProductOptionGroup>>{},
    List<SellerStoreOptionTemplate> optionTemplates = const [],
  })  : _products =
  List<SellerProduct>.of(
    products,
  ),
        _categories =
        List<SellerCategory>.of(
          categories,
        ),
        _optionGroups = optionGroups.map(
              (
              int key,
              List<SellerProductOptionGroup>
              value,
              ) {
            return MapEntry(
              key,
              List<SellerProductOptionGroup>
                  .of(value),
            );
          },
        ),
        _optionTemplates = List.of(optionTemplates) {
    for (final SellerProduct product
    in products) {
      final bool categoryExists =
      _categories.any(
            (SellerCategory item) {
          return item.storeId ==
              product.storeId &&
              item.categoryId ==
                  product.categoryId;
        },
      );

      if (!categoryExists) {
        _categories.add(
          SellerCategory(
            storeId: product.storeId,
            categoryId:
            product.categoryId,
            name: product.categoryName,
            displayOrder: _categories
                .where(
                  (
                  SellerCategory item,
                  ) =>
              item.storeId ==
                  product.storeId,
            )
                .length,
          ),
        );
      }
    }
  }

  final List<SellerProduct> _products;
  final List<SellerCategory> _categories;
  final Map<
      int,
      List<SellerProductOptionGroup>>
  _optionGroups;
  final List<SellerStoreOptionTemplate> _optionTemplates;

  @override
  Future<List<SellerCategory>>
  findCategories(
      int storeId,
      ) async {
    final List<SellerCategory> result =
    <SellerCategory>[
      ..._categories.where(
            (SellerCategory item) =>
        item.storeId == storeId,
      ),
    ];

    result.sort(
          (
          SellerCategory left,
          SellerCategory right,
          ) {
        return left.displayOrder.compareTo(
          right.displayOrder,
        );
      },
    );

    return List<SellerCategory>.unmodifiable(
      result,
    );
  }

  @override
  Future<SellerCategory> createCategory(
      int storeId, {
        required String name,
        required int displayOrder,
      }) async {
    final int nextId =
        _categories.fold<int>(
          0,
              (
              int value,
              SellerCategory item,
              ) {
            return item.categoryId >
                value
                ? item.categoryId
                : value;
          },
        ) +
            1;

    final SellerCategory created =
    SellerCategory(
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
    final int index =
    _categories.indexWhere(
          (SellerCategory item) {
        return item.storeId == storeId &&
            item.categoryId == categoryId;
      },
    );

    if (index < 0) {
      throw StateError(
        'category not found in '
            'selected store',
      );
    }

    final SellerCategory updated =
    SellerCategory(
      storeId: storeId,
      categoryId: categoryId,
      name: name,
      displayOrder: displayOrder,
      status: _categories[index].status,
    );

    _categories[index] = updated;

    for (int i = 0;
    i < _products.length;
    i++) {
      final SellerProduct product =
      _products[i];

      if (product.storeId == storeId &&
          product.categoryId ==
              categoryId) {
        _products[i] = product.copyWith(
          categoryName: name,
        );
      }
    }

    return updated;
  }

  @override
  Future<void> deleteCategory(
      int storeId,
      int categoryId,
      ) async {
    final bool hasProducts =
    _products.any(
          (SellerProduct product) {
        return product.storeId == storeId &&
            product.categoryId ==
                categoryId;
      },
    );

    if (hasProducts) {
      throw StateError(
        'category still has products',
      );
    }

    final int index =
    _categories.indexWhere(
          (SellerCategory category) {
        return category.storeId ==
            storeId &&
            category.categoryId ==
                categoryId;
      },
    );

    if (index < 0) {
      throw StateError(
        'category not found in '
            'selected store',
      );
    }

    _categories.removeAt(index);
  }

  @override
  Future<String> uploadProductImage(
      String filePath,
      ) async {
    return filePath;
  }

  @override
  Future<String> uploadProductImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    return 'memory://product-images/$fileName';
  }

  @override
  Future<List<SellerProduct>> findAll(
      int storeId,
      ) async {
    return List<SellerProduct>.unmodifiable(
      _products.where(
            (SellerProduct product) =>
        product.storeId == storeId,
      ),
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
    final SellerCategory category =
    (await findCategories(storeId))
        .firstWhere(
          (SellerCategory item) {
        return item.categoryId ==
            categoryId;
      },
    );

    final int nextId =
        _products.fold<int>(
          0,
              (
              int value,
              SellerProduct item,
              ) {
            return item.productId >
                value
                ? item.productId
                : value;
          },
        ) +
            1;

    final SellerProduct created =
    SellerProduct(
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
    final int index =
    _products.indexWhere(
          (SellerProduct item) {
        return item.storeId == storeId &&
            item.productId ==
                product.productId;
      },
    );

    if (index < 0 ||
        product.storeId != storeId) {
      throw StateError(
        'product not found in selected store',
      );
    }

    final SellerCategory category =
    (await findCategories(storeId))
        .firstWhere(
          (SellerCategory item) {
        return item.categoryId ==
            categoryId;
      },
    );

    final SellerProduct updated =
    SellerProduct(
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
      availableForQr:
      product.availableForQr,
      availableForCustomerApp:
      product.availableForCustomerApp,
      salesStartAt:
      product.salesStartAt,
      salesEndAt: product.salesEndAt,
      qrWebEnabled:
      product.qrWebEnabled,
      customerAppEnabled:
      product.customerAppEnabled,
    );

    _products[index] = updated;

    return updated;
  }

  @override
  Future<void> deleteProduct(
      int storeId,
      SellerProduct product,
      ) async {
    final int index =
    _products.indexWhere(
          (SellerProduct candidate) {
        return candidate.storeId ==
            storeId &&
            candidate.productId ==
                product.productId;
      },
    );

    if (index < 0 ||
        product.storeId != storeId) {
      throw StateError(
        'product not found in selected store',
      );
    }

    _products.removeAt(index);
    _optionGroups.remove(
      product.productId,
    );
  }

  @override
  Future<SellerProductDetail> findOne(
      int storeId,
      SellerProduct product,
      ) async {
    final Iterable<SellerProduct> stored =
    _products.where(
          (SellerProduct item) {
        return item.storeId == storeId &&
            item.productId ==
                product.productId;
      },
    );

    if (stored.isEmpty ||
        product.storeId != storeId) {
      throw StateError(
        'product not found in selected store',
      );
    }

    return SellerProductDetail(
      product: stored.single,
      optionGroups: List<
          SellerProductOptionGroup>.unmodifiable(
        _optionGroups[product.productId] ??
            const <
                SellerProductOptionGroup>[],
      ),
    );
  }

  @override
  Future<SellerProductDetail>
  replaceOptions(
      int storeId,
      SellerProduct product,
      List<SellerProductOptionGroup> groups,
      ) async {
    final SellerProductDetail detail =
    await findOne(
      storeId,
      product,
    );

    _optionGroups[product.productId] =
    List<SellerProductOptionGroup>.of(
      groups,
    );

    return SellerProductDetail(
      product: detail.product,
      optionGroups: List<
          SellerProductOptionGroup>.unmodifiable(
        groups,
      ),
    );
  }

  @override
  Future<List<SellerStoreOptionTemplate>> findOptionTemplates(
    int storeId,
  ) async {
    final result = _optionTemplates
        .where((template) => template.storeId == storeId)
        .toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return List.unmodifiable(result);
  }

  @override
  Future<SellerStoreOptionTemplate> createOptionTemplate(
    int storeId,
    SellerProductOptionGroup group,
  ) async {
    if (_optionTemplates.any(
      (template) => template.storeId == storeId &&
          template.name.toLowerCase() == group.name.toLowerCase(),
    )) {
      throw StateError('option template already exists');
    }
    final nextId = _optionTemplates.fold<int>(
          0,
          (value, template) =>
              template.templateId > value ? template.templateId : value,
        ) +
        1;
    final created = SellerStoreOptionTemplate(
      templateId: nextId,
      storeId: storeId,
      name: group.name,
      minSelect: group.minSelect,
      maxSelect: group.maxSelect,
      required: group.required,
      version: 1,
      options: List.of(group.options),
    );
    _optionTemplates.add(created);
    return created;
  }

  @override
  Future<SellerOptionTemplateUsage> findOptionTemplateUsage(
    int storeId,
    int templateId,
  ) async {
    final products = <SellerOptionTemplateProduct>[];
    for (final product in _products.where((item) => item.storeId == storeId)) {
      final usesTemplate = (_optionGroups[product.productId] ?? const [])
          .any((group) => group.templateId == templateId);
      if (usesTemplate) {
        products.add(SellerOptionTemplateProduct(
          productId: product.productId,
          productName: product.name,
        ));
      }
    }
    return SellerOptionTemplateUsage(
      templateId: templateId,
      totalCount: products.length,
      products: products,
    );
  }

  @override
  Future<SellerStoreOptionTemplate> applyOptionTemplateToAll(
    int storeId,
    SellerProduct product,
    SellerProductOptionGroup group,
  ) async {
    final templateId = group.templateId;
    if (templateId == null) throw StateError('template is required');
    final index = _optionTemplates.indexWhere(
      (template) =>
          template.storeId == storeId && template.templateId == templateId,
    );
    if (index < 0) throw StateError('option template not found');
    final nextVersion = _optionTemplates[index].version + 1;
    final updatedTemplate = SellerStoreOptionTemplate(
      templateId: templateId,
      storeId: storeId,
      name: group.name,
      minSelect: group.minSelect,
      maxSelect: group.maxSelect,
      required: group.required,
      version: nextVersion,
      options: List.of(group.options),
    );
    _optionTemplates[index] = updatedTemplate;
    for (final productId in _optionGroups.keys.toList()) {
      _optionGroups[productId] = _optionGroups[productId]!.map((candidate) {
        if (candidate.templateId != templateId) return candidate;
        return SellerProductOptionGroup(
          optionGroupId: candidate.optionGroupId,
          name: group.name,
          minSelect: group.minSelect,
          maxSelect: group.maxSelect,
          required: group.required,
          displayOrder: candidate.displayOrder,
          templateId: templateId,
          appliedTemplateVersion: nextVersion,
          options: List.of(group.options),
        );
      }).toList();
    }
    return updatedTemplate;
  }

  @override
  Future<void> deleteOptionTemplate(int storeId, int templateId) async {
    final usage = await findOptionTemplateUsage(storeId, templateId);
    if (usage.totalCount > 0) {
      throw StateError('option template is still in use');
    }
    _optionTemplates.removeWhere(
      (template) =>
          template.storeId == storeId && template.templateId == templateId,
    );
  }

  @override
  Future<SellerProduct>
  updateAvailability(
      int storeId,
      SellerProduct product, {
        bool? soldOut,
        bool? qrWebEnabled,
        bool? customerAppEnabled,
      }) async {
    final int index =
    _products.indexWhere(
          (SellerProduct candidate) {
        return candidate.storeId ==
            storeId &&
            candidate.productId ==
                product.productId;
      },
    );

    if (index < 0 ||
        product.storeId != storeId) {
      throw StateError(
        'product not found in selected store',
      );
    }

    final bool nextSoldOut =
        soldOut ?? product.soldOut;

    final bool nextQrEnabled =
        qrWebEnabled ??
            product.qrWebEnabled;

    final bool nextCustomerEnabled =
        customerAppEnabled ??
            product.customerAppEnabled;

    final SellerProduct updated =
    product.copyWith(
      soldOut: nextSoldOut,
      qrWebEnabled: nextQrEnabled,
      customerAppEnabled:
      nextCustomerEnabled,
      availableForQr:
      !nextSoldOut && nextQrEnabled,
      availableForCustomerApp:
      !nextSoldOut &&
          nextCustomerEnabled,
    );

    _products[index] = updated;

    return updated;
  }
}
