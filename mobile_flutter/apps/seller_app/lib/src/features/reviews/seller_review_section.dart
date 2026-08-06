import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'seller_review_repository.dart';

class SellerReviewSection extends StatefulWidget {
  const SellerReviewSection({
    required this.storeId,
    required this.canReply,
    required this.repository,
    super.key,
  });

  final int storeId;
  final bool canReply;
  final SellerReviewRepository repository;

  @override
  State<SellerReviewSection> createState() => _SellerReviewSectionState();
}

class _SellerReviewSectionState extends State<SellerReviewSection> {
  int? _rating;
  var _unanswered = false;
  late Future<List<SellerReview>> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = _load();
  }

  @override
  void didUpdateWidget(covariant SellerReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(PopqSpacing.sm),
            children: [
              ChoiceChip(
                label: const Text('전체 별점'),
                selected: _rating == null,
                onSelected: (_) => _changeFilter(null),
              ),
              for (var value = 5; value >= 1; value--) ...[
                const SizedBox(width: PopqSpacing.xs),
                ChoiceChip(
                  label: Text('$value점'),
                  selected: _rating == value,
                  onSelected: (_) => _changeFilter(value),
                ),
              ],
              const SizedBox(width: PopqSpacing.sm),
              FilterChip(
                label: const Text('미답변'),
                selected: _unanswered,
                onSelected: (value) {
                  setState(() {
                    _unanswered = value;
                    _reviews = _load();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<SellerReview>>(
            future: _reviews,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const PopqLoadingView(message: '리뷰를 불러오고 있어요.');
              }
              if (snapshot.hasError) {
                return PopqErrorView(message: '리뷰를 불러오지 못했습니다.', onRetry: _reload);
              }
              final reviews = snapshot.data ?? const <SellerReview>[];
              if (reviews.isEmpty) {
                return const PopqEmptyView(
                  icon: Icons.reviews_outlined,
                  title: '조건에 맞는 리뷰가 없어요.',
                  description: '별점 또는 미답변 필터를 바꿔 보세요.',
                );
              }
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: const EdgeInsets.all(PopqSpacing.md),
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: PopqSpacing.sm),
                  itemBuilder: (context, index) => _reviewCard(reviews[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _reviewCard(SellerReview review) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(List.filled(review.rating, '★').join()),
              ],
            ),
            if (review.content?.isNotEmpty ?? false) ...[
              const SizedBox(height: PopqSpacing.sm),
              Text(review.content!),
            ],
            if (review.sellerReply?.isNotEmpty ?? false) ...[
              const Divider(),
              Text('사장님 답글\n${review.sellerReply!}'),
            ],
            if (widget.canReply) ...[
              const SizedBox(height: PopqSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _editReply(review),
                    child: Text(review.sellerReply == null ? '답글 작성' : '답글 수정'),
                  ),
                  if (review.sellerReply != null)
                    TextButton(
                      onPressed: () => _deleteReply(review),
                      child: const Text('답글 삭제'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<List<SellerReview>> _load() => widget.repository.findAll(
        widget.storeId,
        rating: _rating,
        unanswered: _unanswered,
      );

  void _changeFilter(int? value) {
    setState(() {
      _rating = value;
      _reviews = _load();
    });
  }

  Future<void> _reload() async {
    setState(() => _reviews = _load());
    await _reviews;
  }

  Future<void> _editReply(SellerReview review) async {
    final controller = TextEditingController(text: review.sellerReply ?? '');
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 답글'),
        content: TextField(controller: controller, maxLength: 1000, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reply == null || !mounted) return;
    try {
      await widget.repository.reply(widget.storeId, review.reviewId, reply);
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) _showError('답글을 저장하지 못했습니다.');
    }
  }

  Future<void> _deleteReply(SellerReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('답글을 삭제할까요?'),
        content: const Text('삭제한 답글은 고객 화면에서도 보이지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteReply(widget.storeId, review.reviewId);
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) _showError('답글을 삭제하지 못했습니다.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
