import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SellerTagBlocks extends StatelessWidget {
  const SellerTagBlocks({
    required this.tags,
    required this.maxCount,
    required this.onAdd,
    required this.onDeleted,
    this.title,
    this.description,
    this.enabled = true,
    super.key,
  });

  final String? title;
  final String? description;
  final List<String> tags;
  final int maxCount;
  final Future<void> Function() onAdd;
  final ValueChanged<String> onDeleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                tooltip: '검색 키워드 추가',
                onPressed: enabled && tags.length < maxCount ? onAdd : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        if (description != null) ...[
          const SizedBox(height: PopqSpacing.xs),
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: PopqSpacing.sm),
        if (tags.isEmpty)
          Text(
            '등록된 검색 키워드가 없습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Wrap(
            spacing: PopqSpacing.sm,
            runSpacing: PopqSpacing.sm,
            children: tags
                .map(
                  (tag) => InputChip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close_rounded, size: 18),
                    onDeleted: enabled ? () => onDeleted(tag) : null,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

Future<String?> showSellerTagInputDialog(
  BuildContext context, {
  required List<String> existingTags,
  int maxLength = 30,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SellerTagInputDialog(
      existingTags: existingTags,
      maxLength: maxLength,
    ),
  );
}

class _SellerTagInputDialog extends StatefulWidget {
  const _SellerTagInputDialog({
    required this.existingTags,
    required this.maxLength,
  });

  final List<String> existingTags;
  final int maxLength;

  @override
  State<_SellerTagInputDialog> createState() => _SellerTagInputDialogState();
}

class _SellerTagInputDialogState extends State<_SellerTagInputDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('검색 키워드 추가'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '키워드',
          hintText: '예: 떡볶이',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('추가'),
        ),
      ],
    );
  }

  void _submit() {
    final tag = _controller.text
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .trim();
    String? error;
    if (tag.isEmpty) {
      error = '추가할 검색 키워드를 입력해 주세요.';
    } else if (tag.contains(',')) {
      error = '키워드는 한 번에 하나씩 추가해 주세요.';
    } else if (tag.length > widget.maxLength) {
      error = '검색 키워드는 ${widget.maxLength}자 이하여야 합니다.';
    } else if (widget.existingTags.any(
      (value) => value.toLowerCase() == tag.toLowerCase(),
    )) {
      error = '이미 추가한 검색 키워드입니다.';
    }
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pop(tag);
  }
}

Future<List<String>?> showSellerTagsEditorDialog(
  BuildContext context, {
  required List<String> initialTags,
  required int maxCount,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _SellerTagsEditorDialog(
      initialTags: initialTags,
      maxCount: maxCount,
    ),
  );
}

class _SellerTagsEditorDialog extends StatefulWidget {
  const _SellerTagsEditorDialog({
    required this.initialTags,
    required this.maxCount,
  });

  final List<String> initialTags;
  final int maxCount;

  @override
  State<_SellerTagsEditorDialog> createState() =>
      _SellerTagsEditorDialogState();
}

class _SellerTagsEditorDialogState extends State<_SellerTagsEditorDialog> {
  late final List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List<String>.of(widget.initialTags);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('검색 키워드 수정'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: SellerTagBlocks(
            title: '키워드 블록',
            description:
                '최대 ${widget.maxCount}개, 키워드당 30자까지 추가할 수 있습니다.',
            tags: _tags,
            maxCount: widget.maxCount,
            onAdd: _add,
            onDeleted: (tag) => setState(() => _tags.remove(tag)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            List<String>.unmodifiable(_tags),
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final tag = await showSellerTagInputDialog(
      context,
      existingTags: _tags,
    );
    if (tag != null && mounted) setState(() => _tags.add(tag));
  }
}
