import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'seller_product_repository.dart';

class SellerCategoryDraft {
  const SellerCategoryDraft({required this.name});

  final String name;
}

class SellerProductDraft {
  const SellerProductDraft({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.basePrice,
    this.imageFilePath,
    this.removeImage = false,
  });

  final int categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int basePrice;

  final String? imageFilePath;
  final bool removeImage;
}

Future<SellerCategoryDraft?> showSellerCategoryEditor(
  BuildContext context, {
  SellerCategory? category,
}) {
  return showDialog<SellerCategoryDraft>(
    context: context,
    builder: (_) => _CategoryEditor(category: category),
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

Future<List<SellerProductOptionGroup>?> showSellerOptionEditor(
  BuildContext context, {
  required SellerProduct product,
  required List<SellerProductOptionGroup> groups,
}) {
  return showDialog<List<SellerProductOptionGroup>>(
    context: context,
    builder: (_) => _OptionEditor(product: product, groups: groups),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.category});

  final SellerCategory? category;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name);
  }

  @override
  void dispose() {
    _name.dispose();
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
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      SellerCategoryDraft(name: name),
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
  late final TextEditingController _price;

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.product?.categoryId ?? widget.categories.first.categoryId;
    _name = TextEditingController(text: widget.product?.name);
    _description = TextEditingController(text: widget.product?.description);
    _price = TextEditingController(
      text: widget.product?.basePrice.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
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
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '메뉴 사진 (선택)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildImagePreview(),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _pickImage(ImageSource.camera);
                      },
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                      ),
                      label: const Text('사진 촬영'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _pickImage(ImageSource.gallery);
                      },
                      icon: const Icon(
                        Icons.photo_library_outlined,
                      ),
                      label: const Text('앨범 선택'),
                    ),
                  ),
                ],
              ),

              if (_pickedImage != null ||
                  (!_removeImage &&
                      widget.product?.imageUrl?.trim().isNotEmpty == true))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearImage,
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: const Text('사진 삭제'),
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

  Future<void> _pickImage(
      ImageSource source,
      ) async {
    final XFile? picked =
    await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) {
      return;
    }

    final Uint8List bytes =
    await picked.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _pickedImage = picked;
      _pickedImageBytes = bytes;
      _removeImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
      _removeImage = true;
    });
  }

  Widget _buildImagePreview() {
    if (_pickedImageBytes != null) {
      return Image.memory(
        _pickedImageBytes!,
        fit: BoxFit.cover,
      );
    }

    final String? existingUrl =
        widget.product?.imageUrl;

    if (!_removeImage &&
        existingUrl != null &&
        existingUrl.trim().isNotEmpty) {
      return Image.network(
        existingUrl,
        fit: BoxFit.cover,
        errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
            ) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 48,
            ),
          );
        },
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
          ),
          SizedBox(height: 8),
          Text('등록된 메뉴 사진이 없습니다.'),
        ],
      ),
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
        description: _nullable(
          _description.text,
        ),
        imageUrl: _removeImage
            ? null
            : widget.product?.imageUrl,
        imageFilePath: _pickedImage?.path,
        removeImage: _removeImage,
        basePrice: price,
      ),
    );
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _OptionEditor extends StatefulWidget {
  const _OptionEditor({required this.product, required this.groups});

  final SellerProduct product;
  final List<SellerProductOptionGroup> groups;

  @override
  State<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<_OptionEditor> {
  late final List<_GroupFields> _groups;

  @override
  void initState() {
    super.initState();
    _groups = widget.groups.map(_GroupFields.fromModel).toList();
  }

  @override
  void dispose() {
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.product.name} 옵션 편집'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: _groups.isEmpty
            ? const Center(
                child: Text('옵션 그룹이 없습니다. 아래 버튼으로 추가하세요.'),
              )
            : ListView.separated(
                itemCount: _groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _groupCard(index),
              ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('add-option-group'),
          onPressed: _addGroup,
          icon: const Icon(Icons.add_rounded),
          label: const Text('그룹 추가'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-options'),
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _groupCard(int groupIndex) {
    final group = _groups[groupIndex];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('option-group-name-$groupIndex'),
                    controller: group.name,
                    decoration: const InputDecoration(labelText: '그룹 이름'),
                  ),
                ),
                IconButton(
                  tooltip: '그룹 삭제',
                  onPressed: () => _removeGroup(groupIndex),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: group.min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '최소 선택'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: group.max,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '최대 선택'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('필수'),
                    value: group.required,
                    onChanged: (value) =>
                        setState(() => group.required = value),
                  ),
                ),
              ],
            ),
            const Divider(),
            ...List.generate(
              group.options.length,
              (optionIndex) => _optionRow(groupIndex, optionIndex),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('add-option-$groupIndex'),
                onPressed: () => setState(
                  () => group.options.add(_OptionFields.empty()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('옵션 항목 추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(int groupIndex, int optionIndex) {
    final option = _groups[groupIndex].options[optionIndex];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            key: Key('option-name-$groupIndex-$optionIndex'),
            controller: option.name,
            decoration: const InputDecoration(labelText: '옵션 이름'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: Key('option-price-$groupIndex-$optionIndex'),
            controller: option.price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '추가 금액'),
          ),
        ),
        IconButton(
          tooltip: '옵션 삭제',
          onPressed: () {
            option.dispose();
            setState(
              () => _groups[groupIndex].options.removeAt(optionIndex),
            );
          },
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }

  void _addGroup() {
    setState(() => _groups.add(_GroupFields.empty()));
  }

  void _removeGroup(int index) {
    _groups[index].dispose();
    setState(() => _groups.removeAt(index));
  }

  void _submit() {
    final result = <SellerProductOptionGroup>[];
    for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++) {
      final group = _groups[groupIndex];
      final name = group.name.text.trim();
      final min = int.tryParse(group.min.text.trim());
      final max = int.tryParse(group.max.text.trim());
      if (name.isEmpty ||
          min == null ||
          max == null ||
          min < 0 ||
          max < min ||
          group.options.isEmpty ||
          max > group.options.length ||
          (group.required && min == 0)) {
        return;
      }
      final options = <SellerProductOption>[];
      for (var optionIndex = 0;
          optionIndex < group.options.length;
          optionIndex++) {
        final fields = group.options[optionIndex];
        final optionName = fields.name.text.trim();
        final price = int.tryParse(fields.price.text.trim());
        if (optionName.isEmpty || price == null || price < 0) return;
        options.add(
          SellerProductOption(
            name: optionName,
            additionalPrice: price,
            displayOrder: optionIndex,
          ),
        );
      }
      result.add(
        SellerProductOptionGroup(
          name: name,
          minSelect: min,
          maxSelect: max,
          required: group.required,
          displayOrder: groupIndex,
          options: options,
        ),
      );
    }
    Navigator.pop(context, result);
  }
}

class _GroupFields {
  _GroupFields({
    required this.name,
    required this.min,
    required this.max,
    required this.required,
    required this.options,
  });

  factory _GroupFields.empty() {
    return _GroupFields(
      name: TextEditingController(),
      min: TextEditingController(text: '0'),
      max: TextEditingController(text: '1'),
      required: false,
      options: [_OptionFields.empty()],
    );
  }

  factory _GroupFields.fromModel(SellerProductOptionGroup group) {
    return _GroupFields(
      name: TextEditingController(text: group.name),
      min: TextEditingController(text: group.minSelect.toString()),
      max: TextEditingController(text: group.maxSelect.toString()),
      required: group.required,
      options: group.options.map(_OptionFields.fromModel).toList(),
    );
  }

  final TextEditingController name;
  final TextEditingController min;
  final TextEditingController max;
  bool required;
  final List<_OptionFields> options;

  void dispose() {
    name.dispose();
    min.dispose();
    max.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _OptionFields {
  _OptionFields({required this.name, required this.price});

  factory _OptionFields.empty() {
    return _OptionFields(
      name: TextEditingController(),
      price: TextEditingController(text: '0'),
    );
  }

  factory _OptionFields.fromModel(SellerProductOption option) {
    return _OptionFields(
      name: TextEditingController(text: option.name),
      price: TextEditingController(text: option.additionalPrice.toString()),
    );
  }

  final TextEditingController name;
  final TextEditingController price;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}
