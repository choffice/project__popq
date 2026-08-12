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
    _reviews = widget.engagementRepository.findPublicReviews(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const StoreBackButton(), title: const Text('리뷰')),
      body: FutureBuilder<CustomerStore>(
        future: _store,
        builder: (BuildContext context, AsyncSnapshot<CustomerStore> storeSnap) {
          return FutureBuilder<List<CustomerReview>>(
            future: _reviews,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<CustomerReview>> reviewSnap,
                ) {
                  if (storeSnap.connectionState != ConnectionState.done ||
                      reviewSnap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!storeSnap.hasData || reviewSnap.hasError) {
                    return Center(
                      child: FilledButton.icon(
                        onPressed: () => setState(_reload),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('리뷰 다시 불러오기'),
                      ),
                    );
                  }
                  final List<CustomerReview> items =
                      reviewSnap.data ?? const [];
                  final double? average = items.isEmpty
                      ? null
                      : items
                                .map((CustomerReview item) => item.rating)
                                .reduce((int left, int right) => left + right) /
                            items.length;
                  return Column(
                    children: <Widget>[
                      StoreSectionTopBar(
                        store: storeSnap.requireData,
                        selected: StoreSection.reviews,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            setState(_reload);
                            try {
                              await Future.wait<Object?>(<Future<Object?>>[
                                _store,
                                _reviews,
                              ]);
                            } catch (_) {
                              // FutureBuilder가 오류 상태와 재시도 버튼을 표시한다.
                            }
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              bottom: PopqSpacing.lg,
                            ),
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.all(PopqSpacing.lg),
                                child: Text(
                                  average == null
                                      ? '아직 등록된 리뷰가 없습니다.'
                                      : '전체 평점 ${average.toStringAsFixed(1)} · 리뷰 ${items.length}개',
                                  style: Theme.of(context).textTheme.titleLarge,
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
                                        if (review.authorEmblemAssetPath !=
                                            null) ...<Widget>[
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
                                                : '${review.authorName} · ${review.authorEmblemLabel}',
                                          ),
                                        ),
                                        Text('${review.rating}점'),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        if (review.content?.trim().isNotEmpty ==
                                            true)
                                          Text(review.content!),
                                        if (review.sellerReply
                                                ?.trim()
                                                .isNotEmpty ==
                                            true)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: PopqSpacing.sm,
                                            ),
                                            child: Text(
                                              '판매자 답글: ${review.sellerReply!}',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
