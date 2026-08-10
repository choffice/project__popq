import 'package:flutter/material.dart';
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
      await widget.repository.createReview(
        orderPublicId: widget.orderPublicId,
        rating: _rating,
        content: _contentController.text.trim(),
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
}
