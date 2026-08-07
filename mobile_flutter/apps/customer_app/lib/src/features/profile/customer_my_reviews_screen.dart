import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';
import 'store_category_filter.dart';

class CustomerMyReviewsScreen extends StatefulWidget {
  const CustomerMyReviewsScreen({
    required this.repository,
    super.key,
  });

  final CustomerEngagementRepository repository;

  @override
  State<CustomerMyReviewsScreen> createState() =>
      _CustomerMyReviewsScreenState();
}

class _CustomerMyReviewsScreenState
    extends State<CustomerMyReviewsScreen> {
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
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const PopqLoadingView(
            message: '내 리뷰를 불러오고 있어요.',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '내 리뷰를 불러오지 못했어요.',
            onRetry: _reload,
          );
        }

        final allReviews = snapshot.requireData
            .where((review) => review.isActive)
            .toList();

        final selectedLabel =
            popqStoreCategoryLabels[_selectedCategoryIndex];
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
                  padding: const EdgeInsets.symmetric(
                    vertical: PopqSpacing.xl,
                  ),
                  child: Text(
                    '$selectedLabel 카테고리의 리뷰가 없어요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                for (final review in reviews)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: PopqSpacing.sm,
                    ),
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

  Future<void> _editReview(
      CustomerReview review,
      ) async {
    final controller = TextEditingController(
      text: review.content ?? '',
    );

    var rating = review.rating;
    var saving = false;

    final updated =
    await showDialog<CustomerReview>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                '${review.storeName} 리뷰 수정',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration:
                    const InputDecoration(
                      labelText: '별점',
                    ),
                    items: [
                      for (var value = 1;
                      value <= 5;
                      value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            '별 $value개',
                          ),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        rating = value;
                      });
                    },
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  TextField(
                    controller: controller,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration:
                    const InputDecoration(
                      labelText: '리뷰 내용',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                    setDialogState(() {
                      saving = true;
                    });

                    try {
                      final result =
                      await widget
                          .repository
                          .updateReview(
                        reviewId:
                        review.reviewId,
                        rating: rating,
                        content: controller
                            .text
                            .trim(),
                      );

                      if (dialogContext
                          .mounted) {
                        Navigator.of(
                          dialogContext,
                        ).pop(result);
                      }
                    } catch (_) {
                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      setDialogState(() {
                        saving = false;
                      });

                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '리뷰를 수정하지 못했어요.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    saving ? '저장 중...' : '저장',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (updated != null && mounted) {
      _reload();
    }
  }

  Future<void> _deleteReview(
      CustomerReview review,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('리뷰를 삭제할까요?'),
          content: const Text(
            '삭제한 리뷰는 스토어에 더 이상 노출되지 않아요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
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
      await widget.repository.deleteReview(
        review.reviewId,
      );

      if (mounted) {
        _reload();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰를 삭제하지 못했어요.'),
        ),
      );
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
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.storeName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                Text(
                  List.filled(
                    review.rating,
                    '★',
                  ).join(),
                ),
              ],
            ),
            if (review.content?.isNotEmpty ??
                false) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(review.content!),
            ],
            Row(
              mainAxisAlignment:
              MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: const Text('수정'),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: const Text('삭제'),
                ),
              ],
            ),
          ],
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
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        child: Text(
          '작성한 리뷰가 없어요.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
