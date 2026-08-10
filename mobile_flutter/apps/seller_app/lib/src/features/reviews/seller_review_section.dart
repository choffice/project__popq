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
  late Future<List<SellerReview>> _allReviews;

  @override
  void initState() {
    super.initState();
    _reviews = _load();
    _allReviews = widget.repository.findAll(widget.storeId);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PopqSpacing.md,
            PopqSpacing.md,
            PopqSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: FutureBuilder<List<SellerReview>>(
                  future: _allReviews,
                  builder: (context, snapshot) {
                    final reviews = snapshot.data ?? const <SellerReview>[];
                    final average = reviews.isEmpty
                        ? null
                        : reviews.map((item) => item.rating).reduce((a, b) => a + b) /
                            reviews.length;
                    return Text(
                      average == null
                          ? '전체 평점 - · 리뷰 0개'
                          : '전체 평점 ${average.toStringAsFixed(1)} · 리뷰 ${reviews.length}개',
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
              ),
              if (widget.canReply)
                OutlinedButton.icon(
                  onPressed: _manageReplyTemplates,
                  icon: const Icon(Icons.quickreply_outlined),
                  label: const Text('대표 답글'),
                ),
            ],
          ),
        ),
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
    setState(() {
      _reviews = _load();
      _allReviews = widget.repository.findAll(widget.storeId);
    });
    await Future.wait([_reviews, _allReviews]);
  }

  Future<void> _editReply(SellerReview review) async {
    List<SellerReviewReplyTemplate> templates;
    try {
      templates = await widget.repository.findReplyTemplates(widget.storeId);
    } catch (_) {
      templates = const [];
    }
    if (!mounted) return;

    final controller = TextEditingController(text: review.sellerReply ?? '');
    var selectedTemplateId = 0;
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('리뷰 답글'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedTemplateId,
                  decoration: const InputDecoration(labelText: '대표 답글 문구'),
                  items: <DropdownMenuItem<int>>[
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('저장된 답글 없음'),
                    ),
                    ...templates.map(
                      (template) => DropdownMenuItem<int>(
                        value: template.templateId,
                        child: Text(
                          template.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedTemplateId = value);
                    if (value == 0) return;
                    controller.text = templates
                        .firstWhere((item) => item.templateId == value)
                        .content;
                  },
                ),
                const SizedBox(height: PopqSpacing.sm),
                TextField(
                  controller: controller,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '답글 내용'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('작성 완료'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (reply == null || !mounted) return;
    try {
      final saved = await widget.repository.reply(
        widget.storeId,
        review.reviewId,
        reply,
      );
      if (mounted) _replaceReview(saved);
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
      final saved = await widget.repository.deleteReply(
        widget.storeId,
        review.reviewId,
      );
      if (mounted) _replaceReview(saved);
    } catch (_) {
      if (mounted) _showError('답글을 삭제하지 못했습니다.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showTopSnackBar(SnackBar(content: Text(message)));
  }

  void _replaceReview(SellerReview saved) {
    List<SellerReview> replace(List<SellerReview> reviews) => reviews
        .map((item) => item.reviewId == saved.reviewId ? saved : item)
        .toList(growable: false);
    setState(() {
      _reviews = _reviews.then(replace);
      _allReviews = _allReviews.then(replace);
    });
  }

  Future<void> _manageReplyTemplates() async {
    List<SellerReviewReplyTemplate> templates;
    try {
      templates = List.of(
        await widget.repository.findReplyTemplates(widget.storeId),
      );
    } catch (_) {
      if (mounted) _showError('대표 답글을 불러오지 못했습니다.');
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('대표 답글 문구'),
          content: SizedBox(
            width: 520,
            child: templates.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: PopqSpacing.lg),
                    child: Text('저장된 답글이 없습니다.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return ListTile(
                        title: Text(template.content),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: '수정',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final value = await _promptTemplateText(
                                  template.content,
                                );
                                if (value == null) return;
                                try {
                                  final saved = await widget.repository
                                      .updateReplyTemplate(
                                      widget.storeId,
                                      template.templateId,
                                      value,
                                    );
                                  setDialogState(() => templates[index] = saved);
                                } catch (_) {
                                  if (mounted) {
                                    _showError('대표 답글을 수정하지 못했습니다.');
                                  }
                                }
                              },
                            ),
                            IconButton(
                              tooltip: '삭제',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await widget.repository.deleteReplyTemplate(
                                    widget.storeId,
                                    template.templateId,
                                  );
                                  setDialogState(
                                    () => templates.removeAt(index),
                                  );
                                } catch (_) {
                                  if (mounted) {
                                    _showError('대표 답글을 삭제하지 못했습니다.');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton.icon(
              onPressed: templates.length >= 20
                  ? null
                  : () async {
                      final value = await _promptTemplateText(null);
                      if (value == null) return;
                      try {
                        final saved =
                            await widget.repository.createReplyTemplate(
                          widget.storeId,
                          value,
                        );
                        setDialogState(() => templates.add(saved));
                      } catch (_) {
                        if (mounted) {
                          _showError('대표 답글을 추가하지 못했습니다.');
                        }
                      }
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('문구 추가'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('완료'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptTemplateText(String? initialValue) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialValue == null ? '대표 답글 추가' : '대표 답글 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1000,
          minLines: 3,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
}
