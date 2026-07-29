import 'package:flutter/material.dart';

import 'seller_product_repository.dart';

class SellerCategoryDraft {
  const SellerCategoryDraft({required this.name, required this.displayOrder});

  final String name;
  final int displayOrder;
}

class SellerProductDraft {
  const SellerProductDraft({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.basePrice,
  });

  final int categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int basePrice;
}

Future<SellerCategoryDraft?> showSellerCategoryEditor(
  BuildContext context, {
  SellerCategory? category,
  required int suggestedOrder,
}) {
  return showDialog<SellerCategoryDraft>(
    context: context,
    builder: (_) =>
        _CategoryEditor(category: category, suggestedOrder: suggestedOrder),
  );
}

Future<SellerProductDraft?> showSellerProductEditor(
  BuildContext context, {
  required List<SellerCategory> categories,
  SellerProduct? product,
}) {
  return showDialog<SellerProductDraft>(
    context: context,
    builder: (_) =>
        _ProductEditor(categories: categories, product: product),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.category, required this.suggestedOrder});

  final SellerCategory? category;
  final int suggestedOrder;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _name;
  late final TextEditingController _order;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name);
    _order = TextEditingController(
      text: (widget.category?.displayOrder ?? widget.suggestedOrder).toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? '카테고리 추가' : '카테고리 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('category-name'),
            controller: _name,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '카테고리 이름'),
          ),
          TextField(
            key: const Key('category-order'),
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '정렬 순서'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-category'),
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final order = int.tryParse(_order.text.trim());
    if (name.isEmpty || order == null || order < 0) return;
    Navigator.pop(
      context,
      SellerCategoryDraft(name: name, displayOrder: order),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.categories, required this.product});

  final List<SellerCategory> categories;
  final SellerProduct? product;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  late int _categoryId;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.product?.categoryId ?? widget.categories.first.categoryId;
    _name = TextEditingController(text: widget.product?.name);
    _description = TextEditingController(text: widget.product?.description);
    _imageUrl = TextEditingController(text: widget.product?.imageUrl);
    _price = TextEditingController(
      text: widget.product?.basePrice.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? '메뉴 추가' : '메뉴 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                key: const Key('product-category'),
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: widget.categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.categoryId,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _categoryId = value);
                },
              ),
              TextField(
                key: const Key('product-name'),
                controller: _name,
                maxLength: 150,
                decoration: const InputDecoration(labelText: '메뉴 이름'),
              ),
              TextField(
                key: const Key('product-price'),
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '기본 가격'),
              ),
              TextField(
                key: const Key('product-description'),
                controller: _description,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '설명 (선택)'),
              ),
              TextField(
                key: const Key('product-image-url'),
                controller: _imageUrl,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: '이미지 URL (선택)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-product'),
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    if (name.isEmpty || price == null || price < 0) return;
    Navigator.pop(
      context,
      SellerProductDraft(
        categoryId: _categoryId,
        name: name,
        description: _nullable(_description.text),
        imageUrl: _nullable(_imageUrl.text),
        basePrice: price,
      ),
    );
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
