import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../profile/customer_engagement_repository.dart';
import 'store_discovery_repository.dart';
import 'store_section_widgets.dart';

class StoreReviewScreen extends StatefulWidget {
  const StoreReviewScreen({
    required this.storeId,
    required this.storeRepository,
    required this.engagementRepository,
    super.key,
  });

  final int storeId;
  final StoreDiscoveryRepository storeRepository;
  final CustomerEngagementRepository engagementRepository;

  @override
  State<StoreReviewScreen> createState() => _StoreReviewScreenState();
}

class _StoreReviewScreenState extends State<StoreReviewScreen> {
  late Future<CustomerStore> _store;
  late Future<List<CustomerReview>> _reviews;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _store = widget.storeRepository.findDetail(widget.storeId);
    _reviews = widget.engagementRepository.findPublicReviews(
      widget.storeId,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);

    try {
      await Future.wait<Object?>(
        <Future<Object?>>[
          _store,
          _reviews,
        ],
      );
    } catch (_) {
      // FutureBuilder에서 오류 상태를 표시합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const StoreBackButton(),
        title: const Text('리뷰'),
      ),
      body: FutureBuilder<CustomerStore>(
        future: _store,
        builder: (
            BuildContext context,
            AsyncSnapshot<CustomerStore> storeSnap,
            ) {
          return FutureBuilder<List<CustomerReview>>(
            future: _reviews,
            builder: (
                BuildContext context,
                AsyncSnapshot<List<CustomerReview>> reviewSnap,
                ) {
              if (storeSnap.connectionState != ConnectionState.done ||
                  reviewSnap.connectionState != ConnectionState.done) {
                return const PopqLoadingView(
                  message: '리뷰를 불러오고 있어요.',
                );
              }

              if (!storeSnap.hasData || reviewSnap.hasError) {
                return PopqErrorView(
                  message: '리뷰를 불러오지 못했어요.',
                  onRetry: () {
                    setState(_reload);
                  },
                );
              }

              final List<CustomerReview> items =
                  reviewSnap.data ?? const <CustomerReview>[];

              final CustomerStore store = storeSnap.requireData;

              return Column(
                children: <Widget>[
                  StoreSectionTopBar(
                    store: store,
                    selected: StoreSection.reviews,
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? RefreshIndicator(
                      onRefresh: _refresh,
                      child: const CustomScrollView(
                        physics:
                        AlwaysScrollableScrollPhysics(),
                        slivers: <Widget>[
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: PopqEmptyView(
                              icon: Icons.reviews_outlined,
                              title: '등록된 리뷰가 없습니다.',
                              description:
                              '고객이 작성한 리뷰가 '
                                  '등록되면 이곳에서 확인할 수 있어요.',
                            ),
                          ),
                        ],
                      ),
                    )
                        : _ReviewList(
                      items: items,
                      onRefresh: _refresh,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.items,
    required this.onRefresh,
  });

  final List<CustomerReview> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final double average =
        items
            .map(
              (CustomerReview item) => item.rating,
        )
            .reduce(
              (int left, int right) => left + right,
        ) /
            items.length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: PopqSpacing.lg,
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            child: Text(
              '전체 평점 ${average.toStringAsFixed(1)} '
                  '· 리뷰 ${items.length}개',
              style: Theme.of(
                context,
              ).textTheme.titleLarge,
            ),
          ),
          for (final CustomerReview review in items)
            Card(
              margin: const EdgeInsets.fromLTRB(
                PopqSpacing.md,
                0,
                PopqSpacing.md,
                PopqSpacing.sm,
              ),
              child: ListTile(
                title: Row(
                  children: <Widget>[
                    if (review.authorEmblemAssetPath != null) ...<Widget>[
                      Image.asset(
                        review.authorEmblemAssetPath!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        semanticLabel:
                        review.authorEmblemLabel,
                      ),
                      const SizedBox(
                        width: PopqSpacing.xs,
                      ),
                    ],
                    Expanded(
                      child: Text(
                        review.authorBadgeTier == 'NONE'
                            ? review.authorName
                            : '${review.authorName} '
                            '· ${review.authorEmblemLabel}',
                      ),
                    ),
                    Text(
                      '${review.rating}점',
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: <Widget>[
                    if (review.content
                        ?.trim()
                        .isNotEmpty ==
                        true)
                      Text(
                        review.content!,
                      ),
                    if (review.imageUrl != null) ...<Widget>[
                      const SizedBox(
                        height: PopqSpacing.sm,
                      ),
                      _ReviewImage(
                        imageUrl: review.imageUrl!,
                      ),
                    ],
                    if (review.sellerReply
                        ?.trim()
                        .isNotEmpty ==
                        true)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: PopqSpacing.sm,
                        ),
                        child: Text(
                          '판매자 답글: '
                              '${review.sellerReply!}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewImage extends StatelessWidget {
  const _ReviewImage({
    required this.imageUrl,
  });

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
          errorBuilder: (_, _, _) {
            return Container(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
              ),
            );
          },
        ),
      ),
    );
  }
}