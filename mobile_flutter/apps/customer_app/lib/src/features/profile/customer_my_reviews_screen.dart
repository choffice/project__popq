import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';
import 'store_category_filter.dart';

class CustomerMyReviewsScreen extends StatefulWidget {
  const CustomerMyReviewsScreen({required this.repository, super.key});

  final CustomerEngagementRepository repository;

  @override
  State<CustomerMyReviewsScreen> createState() =>
      _CustomerMyReviewsScreenState();
}

class _CustomerMyReviewsScreenState extends State<CustomerMyReviewsScreen> {
  late Future<List<CustomerReview>> _reviews;
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _reviews = widget.repository.findMyReviews();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerReview>>(
      future: _reviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(message: '내 리뷰를 불러오고 있어요.');
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(message: '내 리뷰를 불러오지 못했어요.', onRetry: _reload);
        }

        final allReviews = snapshot.requireData
            .where((review) => review.isActive)
            .toList();

        final selectedLabel = popqStoreCategoryLabels[_selectedCategoryIndex];
        final reviews = allReviews
            .where(
              (review) => matchesStoreCategoryLabel(
                review.storeCategory,
                selectedLabel,
              ),
            )
            .toList();

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              PopqCategoryTabsRow(
                selectedIndex: _selectedCategoryIndex,
                onSelected: (index) {
                  setState(() => _selectedCategoryIndex = index);
                },
              ),
              const SizedBox(height: PopqSpacing.md),
              if (allReviews.isEmpty)
                const _EmptyReviews()
              else if (reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PopqSpacing.xl),
                  child: Text(
                    '$selectedLabel 카테고리의 리뷰가 없어요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                for (final review in reviews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PopqSpacing.sm),
                    child: _ReviewCard(
                      review: review,
                      onEdit: () => _editReview(review),
                      onDelete: () => _deleteReview(review),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _reload() {
    setState(() {
      _reviews = widget.repository.findMyReviews();
    });
  }

  Future<void> _editReview(CustomerReview review) async {
    final updated = await showDialog<CustomerReview>(
      context: context,
      builder: (_) =>
          _EditReviewDialog(review: review, repository: widget.repository),
    );

    if (updated != null && mounted) {
      _reload();
    }
  }

  Future<void> _deleteReview(CustomerReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('리뷰를 삭제할까요?'),
          content: const Text('삭제한 리뷰는 스토어에 더 이상 노출되지 않아요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.repository.deleteReview(review.reviewId);

      if (mounted) {
        _reload();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('리뷰를 삭제하지 못했어요.')));
    }
  }
}

class _EditReviewDialog extends StatefulWidget {
  const _EditReviewDialog({required this.review, required this.repository});

  final CustomerReview review;
  final CustomerEngagementRepository repository;

  @override
  State<_EditReviewDialog> createState() => _EditReviewDialogState();
}

class _EditReviewDialogState extends State<_EditReviewDialog> {
  late final TextEditingController _controller;
  final ImagePicker _imagePicker = ImagePicker();
  late int _rating;
  bool _saving = false;
  bool _removeExistingImage = false;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.review.content ?? '');
    _rating = widget.review.rating;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingImage =
        !_removeExistingImage && widget.review.imageUrl != null;
    return AlertDialog(
      title: Text('${widget.review.storeName} 리뷰 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(labelText: '별점'),
              items: [
                for (var value = 1; value <= 5; value++)
                  DropdownMenuItem(value: value, child: Text('별 $value개')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _rating = value);
                    },
            ),
            const SizedBox(height: PopqSpacing.md),
            TextField(
              controller: _controller,
              maxLength: 1000,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '리뷰 내용',
                alignLabelWithHint: true,
              ),
            ),
            Row(
              children: [
                const Expanded(child: Text('사진 (선택)')),
                TextButton.icon(
                  onPressed: _saving ? null : _chooseImageSource,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _pickedImageBytes == null && !hasExistingImage
                        ? '사진 추가'
                        : '사진 변경',
                  ),
                ),
              ],
            ),
            if (_pickedImageBytes != null)
              _memoryPreview(_pickedImageBytes!)
            else if (hasExistingImage)
              _ReviewNetworkImage(imageUrl: widget.review.imageUrl!),
            if (_pickedImageBytes != null || hasExistingImage)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _saving ? null : _removeImage,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('사진 제거'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '저장 중...' : '저장'),
        ),
      ],
    );
  }

  Widget _memoryPreview(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
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
      _removeExistingImage = true;
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? imageUrl = _removeExistingImage ? null : widget.review.imageUrl;
      final bytes = _pickedImageBytes;
      final picked = _pickedImage;
      if (bytes != null && bytes.isNotEmpty && picked != null) {
        imageUrl = await widget.repository.uploadReviewImage(
          bytes,
          fileName: picked.name,
        );
      }
      final result = await widget.repository.updateReview(
        reviewId: widget.review.reviewId,
        rating: _rating,
        content: _controller.text.trim(),
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('리뷰를 수정하지 못했어요.')));
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerReview review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.storeName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(List.filled(review.rating, '★').join()),
              ],
            ),
            if (review.authorEmblemAssetPath != null) ...[
              const SizedBox(height: PopqSpacing.xs),
              Row(
                children: [
                  Image.asset(
                    review.authorEmblemAssetPath!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    semanticLabel: review.authorEmblemLabel,
                  ),
                  const SizedBox(width: PopqSpacing.xs),
                  Text(
                    '${review.authorName} · ${review.authorEmblemLabel}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ],
            if (review.content?.isNotEmpty ?? false) ...[
              const SizedBox(height: PopqSpacing.sm),
              Text(review.content!),
            ],
            if (review.imageUrl != null) ...[
              const SizedBox(height: PopqSpacing.sm),
              _ReviewNetworkImage(imageUrl: review.imageUrl!),
            ],
            if (review.sellerReply?.isNotEmpty ?? false) ...[
              const SizedBox(height: PopqSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(PopqSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('사장님 답글\n${review.sellerReply!}'),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onEdit, child: const Text('수정')),
                TextButton(onPressed: onDelete, child: const Text('삭제')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewNetworkImage extends StatelessWidget {
  const _ReviewNetworkImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        child: Text('작성한 리뷰가 없어요.', textAlign: TextAlign.center),
      ),
    );
  }
}
