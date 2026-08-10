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
        message: '?ㅽ넗???곹뭹??遺덈윭?ㅺ퀬 ?덉뼱??',
      );
    }

    if (_error != null ||
        _products == null ||
        _categories == null) {
      return PopqErrorView(
        message: '?좏깮???ㅽ넗?댁쓽 ?곹뭹??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
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
                    '硫붾돱 援ъ꽦',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(
                    height: PopqSpacing.xs,
                  ),
                  Text(
                    '移댄뀒怨좊━瑜?留뚮뱺 ??硫붾돱? ?듭뀡???깅줉?????덉뒿?덈떎.',
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
                      '移댄뀒怨좊━ 異붽?',
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
                      '硫붾돱 異붽?',
                    ),
                  ),
                  if (categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: PopqSpacing.sm,
                      ),
                      child: Text(
                        '硫붾돱瑜?異붽??섎젮硫?移댄뀒怨좊━瑜?癒쇱? ?깅줉??二쇱꽭??',
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
                            '?깅줉??移댄뀒怨좊━',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                        Text(
                          '?좏깮?섎㈃ ?섏젙',
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
                  '?곹뭹紐??먮뒗 移댄뀒怨좊━ 寃??,
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
                    '?꾩껜',
                  ),
                  _filterChip(
                    _ProductFilter.selling,
                    '?먮ℓ 以?,
                  ),
                  _filterChip(
                    _ProductFilter.soldOut,
                    '?덉젅',
                  ),
                  _filterChip(
                    _ProductFilter.channelOff,
                    '梨꾨꼸 爰쇱쭚',
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
                title: '議곌굔??留욌뒗 ?곹뭹???놁뼱??',
                description:
                '硫붾돱瑜?異붽??섍굅??寃?됱뼱? ?꾪꽣瑜?蹂寃쏀빐 二쇱꽭??',
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
      '移댄뀒怨좊━ ??젣',
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
              '${product.categoryName} 쨌 '
                  '${sellerWon(product.basePrice)}',
            ),
            trailing: Chip(
              label: Text(
                product.soldOut
                    ? '?덉젅'
                    : '?먮ℓ 以?,
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
                    '?듭뀡 ?몄쭛',
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
                    '湲곕낯?뺣낫 ?섏젙',
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
                        ? '??젣 以?
                        : '硫붾돱 ??젣',
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
            title: const Text('?덉젅 泥섎━'),
            subtitle: const Text(
              '耳쒕㈃ 紐⑤뱺 ?먮ℓ 梨꾨꼸?먯꽌 利됱떆 二쇰Ц?????놁뒿?덈떎.',
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
            title: const Text('怨좉컼 ???먮ℓ'),
            subtitle: Text(
              product.customerAppEnabled
                  ? '?몄텧 ?덉슜'
                  : '?몄텧 以묒?',
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
            title: const Text('QR ???먮ℓ'),
            subtitle: Text(
              product.qrWebEnabled
                  ? '?몄텧 ?덉슜'
                  : '?몄텧 以묒?',
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
        '${saved.name} 移댄뀒怨좊━瑜???ν뻽?듬땲??',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '移댄뀒怨좊━瑜???ν븯吏 紐삵뻽?듬땲??',
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
        '移댄뀒怨좊━瑜?癒쇱? ?깅줉??二쇱꽭??',
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
        '${saved.name} 硫붾돱瑜???ν뻽?듬땲??',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '硫붾돱瑜???ν븯吏 紐삵뻽?듬땲??',
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
        '${saved.product.name} ?듭뀡 洹몃９ '
            '${saved.optionGroups.length}媛쒕? ??ν뻽?듬땲??',
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
        '?듭뀡????ν븯吏 紐삵뻽?듬땲??',
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
        '${updated.name} ?먮ℓ ?곹깭瑜?蹂寃쏀뻽?듬땲??',
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
        '?곹뭹 ?먮ℓ ?곹깭瑜?蹂寃쏀븯吏 紐삵뻽?듬땲??',
      );
    }
  }

  Future<void> _confirmDeleteProduct(
      SellerProduct product,
      ) async {
    final bool confirmed =
    await _showDeleteDialog(
      title: '硫붾돱 ??젣',
      message:
      '${product.name} 硫붾돱瑜???젣?좉퉴??\n\n'
          '?먮ℓ??諛?怨좉컼 硫붾돱 紐⑸줉?먯꽌???щ씪吏吏留?'
          '湲곗〈 二쇰Ц怨?寃곗젣 湲곕줉? 蹂댁〈?⑸땲??',
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
        '${product.name} 硫붾돱瑜???젣?덉뒿?덈떎.',
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
        '硫붾돱瑜???젣?섏? 紐삵뻽?듬땲??',
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
        '??移댄뀒怨좊━???깅줉??硫붾돱媛 ?덉뒿?덈떎. '
            '硫붾돱瑜?癒쇱? ??젣??二쇱꽭??',
      );

      return;
    }

    final bool confirmed =
    await _showDeleteDialog(
      title: '移댄뀒怨좊━ ??젣',
      message:
      '${category.name} 移댄뀒怨좊━瑜???젣?좉퉴??\n\n'
          '??젣??移댄뀒怨좊━??硫붾돱 ?깅줉 ?붾㈃?먯꽌 ???댁긽 ?쒖떆?섏? ?딆뒿?덈떎.',
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
        '${category.name} 移댄뀒怨좊━瑜???젣?덉뒿?덈떎.',
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
        '移댄뀒怨좊━瑜???젣?섏? 紐삵뻽?듬땲?? '
            '?곌껐??硫붾돱媛 ?녿뒗吏 ?뺤씤??二쇱꽭??',
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
              child: const Text('痍⑥냼'),
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
              child: const Text('??젣'),
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
