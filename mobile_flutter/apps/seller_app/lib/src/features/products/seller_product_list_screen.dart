import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../orders/seller_order_list_screen.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_product_editor.dart';
import 'seller_product_repository.dart';

enum _ProductFilter {
  all,
  selling,
  soldOut,
  channelOff,
}

class SellerProductListScreen extends StatefulWidget {
  const SellerProductListScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerProductRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerProductListScreen> createState() {
    return _SellerProductListScreenState();
  }
}

class _SellerProductListScreenState
    extends State<SellerProductListScreen> {
  List<SellerProduct>? _products;
  List<SellerCategory>? _categories;

  Object? _error;

  bool _loading = true;
  String _query = '';
  _ProductFilter _filter = _ProductFilter.all;

  final Set<int> _updatingIds = <int>{};
  final Set<int> _deletingProductIds = <int>{};
  final Set<int> _deletingCategoryIds = <int>{};

  int get _storeId {
    final int? storeId =
        widget.selectionController.selectedStoreId;

    if (storeId == null) {
      throw StateError(
        'selected store is missing',
      );
    }

    return storeId;
  }

  List<SellerProduct> get _visibleProducts {
    final String normalizedQuery =
    _query.trim().toLowerCase();

    return (_products ?? const <SellerProduct>[])
        .where(
          (SellerProduct product) {
        final bool matchesQuery =
            normalizedQuery.isEmpty ||
                product.name
                    .toLowerCase()
                    .contains(normalizedQuery) ||
                product.categoryName
                    .toLowerCase()
                    .contains(normalizedQuery);

        final bool matchesFilter =
        switch (_filter) {
          _ProductFilter.all => true,
          _ProductFilter.selling =>
          !product.soldOut,
          _ProductFilter.soldOut =>
          product.soldOut,
          _ProductFilter.channelOff =>
          !product.qrWebEnabled ||
              !product.customerAppEnabled,
        };

        return matchesQuery && matchesFilter;
      },
    ).toList();
  }

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(
        message: '스토어 상품을 불러오고 있어요.',
      );
    }

    if (_error != null ||
        _products == null ||
        _categories == null) {
      return PopqErrorView(
        message: '선택한 스토어의 상품을 불러오지 못했습니다.',
        onRetry: _load,
      );
    }

    final List<SellerCategory> categories =
    _categories!;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '메뉴 구성',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(
                    height: PopqSpacing.xs,
                  ),
                  Text(
                    '카테고리를 만든 뒤 메뉴와 옵션을 등록할 수 있습니다.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  OutlinedButton.icon(
                    key: const Key(
                      'add-category',
                    ),
                    onPressed: () {
                      _editCategory();
                    },
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                    ),
                    label: const Text(
                      '카테고리 추가',
                    ),
                  ),
                  const SizedBox(
                    height: PopqSpacing.sm,
                  ),
                  FilledButton.icon(
                    key: const Key(
                      'add-product',
                    ),
                    onPressed: categories.isEmpty
                        ? null
                        : () {
                      _editProduct();
                    },
                    icon: const Icon(
                      Icons.add_rounded,
                    ),
                    label: const Text(
                      '메뉴 추가',
                    ),
                  ),
                  if (categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: PopqSpacing.sm,
                      ),
                      child: Text(
                        '메뉴를 추가하려면 카테고리를 먼저 등록해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(
                      height: PopqSpacing.lg,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '등록된 카테고리',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                        Text(
                          '선택하면 수정',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Wrap(
                      spacing: PopqSpacing.xs,
                      runSpacing: PopqSpacing.xs,
                      children: categories.map(
                            (SellerCategory category) {
                          return _categoryChip(
                            category,
                          );
                        },
                      ).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.sm,
              PopqSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                decoration:
                const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                  ),
                  hintText:
                  '상품명 또는 카테고리 검색',
                ),
                onChanged: (String value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection:
                Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: PopqSpacing.md,
                  vertical: PopqSpacing.sm,
                ),
                children: [
                  _filterChip(
                    _ProductFilter.all,
                    '전체',
                  ),
                  _filterChip(
                    _ProductFilter.selling,
                    '판매 중',
                  ),
                  _filterChip(
                    _ProductFilter.soldOut,
                    '품절',
                  ),
                  _filterChip(
                    _ProductFilter.channelOff,
                    '채널 꺼짐',
                  ),
                ],
              ),
            ),
          ),
          if (_visibleProducts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PopqEmptyView(
                icon:
                Icons.inventory_2_outlined,
                title: '조건에 맞는 상품이 없어요.',
                description:
                '메뉴를 추가하거나 검색어와 필터를 변경해 주세요.',
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
                itemCount:
                _visibleProducts.length,
                separatorBuilder: (
                    BuildContext context,
                    int index,
                    ) {
                  return const SizedBox(
                    height: PopqSpacing.md,
                  );
                },
                itemBuilder: (
                    BuildContext context,
                    int index,
                    ) {
                  return _productCard(
                    _visibleProducts[index],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(
      SellerCategory category,
      ) {
    final bool deleting =
    _deletingCategoryIds.contains(
      category.categoryId,
    );

    return InputChip(
      key: Key(
        'category-${category.categoryId}',
      ),
      avatar: const Icon(
        Icons.edit_outlined,
        size: 16,
      ),
      label: Text(
        '${category.displayOrder}. '
            '${category.name}',
      ),
      onPressed: deleting
          ? null
          : () {
        _editCategory(category);
      },
      onDeleted: deleting
          ? null
          : () {
        _confirmDeleteCategory(
          category,
        );
      },
      deleteIcon: deleting
          ? const SizedBox.square(
        dimension: 16,
        child:
        CircularProgressIndicator(
          strokeWidth: 2,
        ),
      )
          : const Icon(
        Icons.delete_outline_rounded,
        size: 18,
      ),
      deleteButtonTooltipMessage:
      '카테고리 삭제',
    );
  }

  Widget _filterChip(
      _ProductFilter filter,
      String label,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        right: PopqSpacing.xs,
      ),
      child: FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) {
          setState(() {
            _filter = filter;
          });
        },
      ),
    );
  }

  Widget _productCard(
      SellerProduct product,
      ) {
    final bool isUpdating =
    _updatingIds.contains(
      product.productId,
    );

    final bool isDeleting =
    _deletingProductIds.contains(
      product.productId,
    );

    final bool isBusy =
        isUpdating || isDeleting;

    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Card(
      key: Key(
        'product-${product.productId}',
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding:
            const EdgeInsets.fromLTRB(
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
                    ? Icons
                    .remove_shopping_cart_outlined
                    : Icons.local_cafe_outlined,
                color: PopqPalette.ink,
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              '${product.categoryName} · '
                  '${sellerWon(product.basePrice)}',
            ),
            trailing: Chip(
              label: Text(
                product.soldOut
                    ? '품절'
                    : '판매 중',
              ),
              backgroundColor: product.soldOut
                  ? const Color(0xFFE7E4EA)
                  : const Color(0xFFD7F0E3),
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: PopqSpacing.sm,
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  key: Key(
                    'edit-options-'
                        '${product.productId}',
                  ),
                  onPressed: isBusy
                      ? null
                      : () {
                    _editOptions(
                      product,
                    );
                  },
                  icon: const Icon(
                    Icons.tune_rounded,
                  ),
                  label: const Text(
                    '옵션 편집',
                  ),
                ),
                TextButton.icon(
                  key: Key(
                    'edit-product-'
                        '${product.productId}',
                  ),
                  onPressed: isBusy
                      ? null
                      : () {
                    _editProduct(
                      product,
                    );
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                  label: const Text(
                    '기본정보 수정',
                  ),
                ),
                TextButton.icon(
                  key: Key(
                    'delete-product-'
                        '${product.productId}',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                    colorScheme.error,
                  ),
                  onPressed: isBusy
                      ? null
                      : () {
                    _confirmDeleteProduct(
                      product,
                    );
                  },
                  icon: isDeleting
                      ? const SizedBox.square(
                    dimension: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.delete_outline_rounded,
                  ),
                  label: Text(
                    isDeleting
                        ? '삭제 중'
                        : '메뉴 삭제',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            key: Key(
              'sold-out-${product.productId}',
            ),
            title: const Text('품절 처리'),
            subtitle: const Text(
              '켜면 모든 판매 채널에서 즉시 주문할 수 없습니다.',
            ),
            value: product.soldOut,
            onChanged: isBusy
                ? null
                : (bool value) {
              _update(
                product,
                soldOut: value,
              );
            },
          ),
          SwitchListTile(
            key: Key(
              'customer-app-'
                  '${product.productId}',
            ),
            title: const Text('고객 앱 판매'),
            subtitle: Text(
              product.customerAppEnabled
                  ? '노출 허용'
                  : '노출 중지',
            ),
            value:
            product.customerAppEnabled,
            onChanged: isBusy
                ? null
                : (bool value) {
              _update(
                product,
                customerAppEnabled:
                value,
              );
            },
          ),
          SwitchListTile(
            key: Key(
              'qr-web-${product.productId}',
            ),
            title: const Text('QR 웹 판매'),
            subtitle: Text(
              product.qrWebEnabled
                  ? '노출 허용'
                  : '노출 중지',
            ),
            value: product.qrWebEnabled,
            onChanged: isBusy
                ? null
                : (bool value) {
              _update(
                product,
                qrWebEnabled: value,
              );
            },
          ),
          if (isBusy)
            const LinearProgressIndicator(),
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
      final List<Object> result =
      await Future.wait<Object>([
        widget.repository.findCategories(
          _storeId,
        ),
        widget.repository.findAll(
          _storeId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = List<SellerCategory>.of(
          result[0] as List<SellerCategory>,
        );

        _products = List<SellerProduct>.of(
          result[1] as List<SellerProduct>,
        );

        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _editCategory([
    SellerCategory? category,
  ]) async {
    final draft =
    await showSellerCategoryEditor(
      context,
      category: category,
      suggestedOrder:
      _categories?.length ?? 0,
    );

    if (draft == null) {
      return;
    }

    try {
      final SellerCategory saved =
      category == null
          ? await widget.repository
          .createCategory(
        _storeId,
        name: draft.name,
        displayOrder:
        draft.displayOrder,
      )
          : await widget.repository
          .updateCategory(
        _storeId,
        category.categoryId,
        name: draft.name,
        displayOrder:
        draft.displayOrder,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final int index =
        _categories!.indexWhere(
              (SellerCategory item) {
            return item.categoryId ==
                saved.categoryId;
          },
        );

        if (index < 0) {
          _categories!.add(saved);
        } else {
          _categories![index] = saved;
        }

        _categories!.sort(
              (
              SellerCategory left,
              SellerCategory right,
              ) {
            return left.displayOrder
                .compareTo(
              right.displayOrder,
            );
          },
        );

        for (int i = 0;
        i < _products!.length;
        i++) {
          final SellerProduct product =
          _products![i];

          if (product.categoryId ==
              saved.categoryId) {
            _products![i] =
                product.copyWith(
                  categoryName: saved.name,
                );
          }
        }
      });

      _showMessage(
        '${saved.name} 카테고리를 저장했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '카테고리를 저장하지 못했습니다.',
      );
    }
  }

  Future<void> _editProduct([
    SellerProduct? product,
  ]) async {
    final List<SellerCategory> categories =
        _categories ??
            const <SellerCategory>[];

    if (categories.isEmpty) {
      _showMessage(
        '카테고리를 먼저 등록해 주세요.',
      );

      return;
    }

    final draft =
    await showSellerProductEditor(
      context,
      categories: categories,
      product: product,
    );

    if (draft == null) {
      return;
    }

    try {
      final SellerProduct saved =
      product == null
          ? await widget.repository.create(
        _storeId,
        categoryId:
        draft.categoryId,
        name: draft.name,
        description:
        draft.description,
        imageUrl: draft.imageUrl,
        basePrice:
        draft.basePrice,
      )
          : await widget.repository.update(
        _storeId,
        product,
        categoryId:
        draft.categoryId,
        name: draft.name,
        description:
        draft.description,
        imageUrl: draft.imageUrl,
        basePrice:
        draft.basePrice,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final int index =
        _products!.indexWhere(
              (SellerProduct item) {
            return item.productId ==
                saved.productId;
          },
        );

        if (index < 0) {
          _products!.add(saved);
        } else {
          _products![index] = saved;
        }
      });

      _showMessage(
        '${saved.name} 메뉴를 저장했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '메뉴를 저장하지 못했습니다.',
      );
    }
  }

  Future<void> _editOptions(
      SellerProduct product,
      ) async {
    setState(() {
      _updatingIds.add(
        product.productId,
      );
    });

    try {
      final SellerProductDetail detail =
      await widget.repository.findOne(
        _storeId,
        product,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _updatingIds.remove(
          product.productId,
        );
      });

      final groups =
      await showSellerOptionEditor(
        context,
        product: detail.product,
        groups: detail.optionGroups,
      );

      if (groups == null || !mounted) {
        return;
      }

      setState(() {
        _updatingIds.add(
          product.productId,
        );
      });

      final SellerProductDetail saved =
      await widget.repository
          .replaceOptions(
        _storeId,
        product,
        groups,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _updatingIds.remove(
          product.productId,
        );
      });

      _showMessage(
        '${saved.product.name} 옵션 그룹 '
            '${saved.optionGroups.length}개를 저장했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _updatingIds.remove(
          product.productId,
        );
      });

      _showMessage(
        '옵션을 저장하지 못했습니다.',
      );
    }
  }

  Future<void> _update(
      SellerProduct product, {
        bool? soldOut,
        bool? qrWebEnabled,
        bool? customerAppEnabled,
      }) async {
    setState(() {
      _updatingIds.add(
        product.productId,
      );
    });

    try {
      final SellerProduct updated =
      await widget.repository
          .updateAvailability(
        _storeId,
        product,
        soldOut: soldOut,
        qrWebEnabled: qrWebEnabled,
        customerAppEnabled:
        customerAppEnabled,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final int index =
        _products!.indexWhere(
              (SellerProduct candidate) {
            return candidate.productId ==
                updated.productId;
          },
        );

        if (index >= 0) {
          _products![index] = updated;
        }

        _updatingIds.remove(
          product.productId,
        );
      });

      _showMessage(
        '${updated.name} 판매 상태를 변경했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _updatingIds.remove(
          product.productId,
        );
      });

      _showMessage(
        '상품 판매 상태를 변경하지 못했습니다.',
      );
    }
  }

  Future<void> _confirmDeleteProduct(
      SellerProduct product,
      ) async {
    final bool confirmed =
    await _showDeleteDialog(
      title: '메뉴 삭제',
      message:
      '${product.name} 메뉴를 삭제할까요?\n\n'
          '판매자 및 고객 메뉴 목록에서는 사라지지만 '
          '기존 주문과 결제 기록은 보존됩니다.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _deleteProduct(product);
  }

  Future<void> _deleteProduct(
      SellerProduct product,
      ) async {
    setState(() {
      _deletingProductIds.add(
        product.productId,
      );
    });

    try {
      await widget.repository.deleteProduct(
        _storeId,
        product,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products!.removeWhere(
              (SellerProduct item) {
            return item.productId ==
                product.productId;
          },
        );

        _updatingIds.remove(
          product.productId,
        );

        _deletingProductIds.remove(
          product.productId,
        );
      });

      _showMessage(
        '${product.name} 메뉴를 삭제했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deletingProductIds.remove(
          product.productId,
        );
      });

      _showMessage(
        '메뉴를 삭제하지 못했습니다.',
      );
    }
  }

  Future<void> _confirmDeleteCategory(
      SellerCategory category,
      ) async {
    final bool hasProducts =
    (_products ??
        const <SellerProduct>[])
        .any(
          (SellerProduct product) {
        return product.categoryId ==
            category.categoryId;
      },
    );

    if (hasProducts) {
      _showMessage(
        '이 카테고리에 등록된 메뉴가 있습니다. '
            '메뉴를 먼저 삭제해 주세요.',
      );

      return;
    }

    final bool confirmed =
    await _showDeleteDialog(
      title: '카테고리 삭제',
      message:
      '${category.name} 카테고리를 삭제할까요?\n\n'
          '삭제한 카테고리는 메뉴 등록 화면에서 더 이상 표시되지 않습니다.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _deleteCategory(category);
  }

  Future<void> _deleteCategory(
      SellerCategory category,
      ) async {
    setState(() {
      _deletingCategoryIds.add(
        category.categoryId,
      );
    });

    try {
      await widget.repository.deleteCategory(
        _storeId,
        category.categoryId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _categories!.removeWhere(
              (SellerCategory item) {
            return item.categoryId ==
                category.categoryId;
          },
        );

        _deletingCategoryIds.remove(
          category.categoryId,
        );
      });

      _showMessage(
        '${category.name} 카테고리를 삭제했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deletingCategoryIds.remove(
          category.categoryId,
        );
      });

      _showMessage(
        '카테고리를 삭제하지 못했습니다. '
            '연결된 메뉴가 없는지 확인해 주세요.',
      );
    }
  }

  Future<bool> _showDeleteDialog({
    required String title,
    required String message,
  }) async {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    final bool? result =
    await showDialog<bool>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                colorScheme.error,
                foregroundColor:
                colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }
}