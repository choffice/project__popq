import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';

class ReviewEditorScreen extends StatefulWidget {
  const ReviewEditorScreen({
    required this.orderPublicId,
    required this.repository,
    super.key,
  });

  final String orderPublicId;
  final CustomerEngagementRepository repository;

  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  final _contentController = TextEditingController();
  var _rating = 5;
  var _saving = false;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰 작성')),
      body: ListView(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Text('주문은 어떠셨나요?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PopqSpacing.sm),
          const Text('완료된 주문에는 리뷰를 한 번만 작성할 수 있어요.'),
          const SizedBox(height: PopqSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var value = 1; value <= 5; value++)
                IconButton(
                  tooltip: '별 $value개',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _rating = value),
                  iconSize: 40,
                  color: PopqPalette.forest,
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                ),
            ],
          ),
          const SizedBox(height: PopqSpacing.lg),
          TextField(
            controller: _contentController,
            enabled: !_saving,
            maxLength: 1000,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '리뷰 내용',
              hintText: '좋았던 점과 아쉬웠던 점을 남겨주세요.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PopqSpacing.md),
          _reviewImageEditor(),
          const SizedBox(height: PopqSpacing.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.rate_review_rounded),
            label: Text(_saving ? '등록 중...' : '리뷰 등록'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? imageUrl;
      final bytes = _pickedImageBytes;
      final file = _pickedImage;
      if (bytes != null && bytes.isNotEmpty && file != null) {
        imageUrl = await widget.repository.uploadReviewImage(
          bytes,
          fileName: file.name,
        );
      }
      await widget.repository.createReview(
        orderPublicId: widget.orderPublicId,
        rating: _rating,
        content: _contentController.text.trim(),
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('리뷰를 등록하지 못했어요.')));
    }
  }

  Widget _reviewImageEditor() {
    final bytes = _pickedImageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '사진 (선택)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _chooseImageSource,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(bytes == null ? '사진 추가' : '사진 변경'),
            ),
          ],
        ),
        if (bytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _pickedImage = null;
                      _pickedImageBytes = null;
                    }),
              icon: const Icon(Icons.close_rounded),
              label: const Text('사진 제거'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = picked;
      _pickedImageBytes = bytes;
    });
  }
}
