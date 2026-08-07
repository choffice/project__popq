import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../profile/customer_engagement_repository.dart';
import 'store_discovery_repository.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({
    required this.storeId,
    required this.repository,
    required this.engagementRepository,
    required this.sessionController,
    super.key,
  });

  final int storeId;
  final StoreDiscoveryRepository repository;
  final CustomerEngagementRepository engagementRepository;
  final SessionController sessionController;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late Future<CustomerStore> _store;
  late Future<List<CustomerReview>> _reviews;
  bool? _interested;
  var _interestSaving = false;

  @override
  void initState() {
    super.initState();
    _store = widget.repository.findDetail(widget.storeId);
    _reviews = widget.engagementRepository.findPublicReviews(widget.storeId);
    if (widget.sessionController.isSignedIn) {
      _loadInterest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('매장 상세'),
        actions: [
          IconButton(
            tooltip: _interested == true ? '관심 스토어 해제' : '관심 스토어 등록',
            onPressed: _interestSaving ? null : _toggleInterest,
            icon: Icon(
              _interested == true
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
        ],
      ),
      body: FutureBuilder<CustomerStore>(
        future: _store,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '스토어 정보를 불러오고 있어요.');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '스토어 상세 정보를 불러오지 못했어요.',
              onRetry: () => setState(() {
                _store = widget.repository.findDetail(widget.storeId);
              }),
            );
          }
          final store = snapshot.requireData;
          final schedule = store.resolvedSchedule;
          return ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              _StoreHeroImage(
                imageUrl: store.imageUrl,
                height: 180,
              ),
              const SizedBox(height: PopqSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Chip(label: Text(_businessStatusLabel(store.businessStatus))),
                ],
              ),
              const SizedBox(height: PopqSpacing.sm),
              Wrap(
                spacing: PopqSpacing.sm,
                runSpacing: PopqSpacing.xs,
                children: [
                  Chip(label: Text(_storeTypeLabel(store.storeType))),
                  if (store.representativeCategory?.trim().isNotEmpty == true)
                    Chip(label: Text(store.representativeCategory!)),
                ],
              ),
              if (store.description != null) ...[
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  store.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (store.fullAddress.isNotEmpty ||
                  store.phone?.trim().isNotEmpty == true ||
                  schedule.businessHours.isNotEmpty) ...[
                const SizedBox(height: PopqSpacing.lg),
                Card(
                  child: Column(
                    children: [
                      if (store.fullAddress.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.place_rounded),
                          title: const Text('위치'),
                          subtitle: Text(store.fullAddress),
                        ),
                      if (store.phone?.trim().isNotEmpty == true) ...[
                        if (store.fullAddress.isNotEmpty)
                          const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.phone_outlined),
                          title: const Text('전화번호'),
                          subtitle: Text(store.phone!),
                        ),
                      ],
                      if (store.fullAddress.isNotEmpty ||
                          store.phone?.trim().isNotEmpty == true)
                        const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.today_outlined),
                        title: const Text('오늘 영업시간'),
                        subtitle: Text(schedule.todayLabel()),
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        leading: const Icon(Icons.schedule_outlined),
                        title: const Text('전체 영업시간'),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          PopqSpacing.lg,
                          0,
                          PopqSpacing.lg,
                          PopqSpacing.md,
                        ),
                        children: schedule.summaryLines()
                            .map((line) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: PopqSpacing.xs,
                                    ),
                                    child: Text(line),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: PopqSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(PopqSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이용 안내',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: PopqSpacing.sm),
                      Wrap(
                        spacing: PopqSpacing.sm,
                        runSpacing: PopqSpacing.sm,
                        children: [
                          _AvailabilityChip(
                            label: '포장',
                            available: store.takeoutAvailable,
                          ),
                          _AvailabilityChip(
                            label: '매장 식사',
                            available: store.dineInAvailable,
                          ),
                          _AvailabilityChip(
                            label: '주문 접수',
                            available: store.orderAcceptingEnabled,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (store.tags.isNotEmpty) ...[
                const SizedBox(height: PopqSpacing.md),
                Wrap(
                  spacing: PopqSpacing.sm,
                  runSpacing: PopqSpacing.xs,
                  children: store.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(),
                ),
              ],
              const SizedBox(height: PopqSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.push(
                  '${CustomerRoutes.stores}/${store.storeId}/products',
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('상품 보기'),
              ),
              const SizedBox(height: PopqSpacing.xl),
              Text('고객 리뷰', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: PopqSpacing.sm),
              _StoreReviewSection(reviews: _reviews),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadInterest() async {
    try {
      final interested = await widget.engagementRepository.isInterested(
        widget.storeId,
      );
      if (mounted) setState(() => _interested = interested);
    } catch (_) {
      if (mounted) setState(() => _interested = false);
    }
  }

  Future<void> _toggleInterest() async {
    if (!widget.sessionController.isSignedIn) {
      final from = Uri.encodeComponent(
        '${CustomerRoutes.stores}/${widget.storeId}',
      );
      context.push('${CustomerRoutes.signIn}?from=$from');
      return;
    }
    setState(() => _interestSaving = true);
    try {
      final interested = _interested == true
          ? await widget.engagementRepository.removeInterest(widget.storeId)
          : await widget.engagementRepository.addInterest(widget.storeId);
      if (!mounted) return;
      setState(() {
        _interested = interested;
        _interestSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(interested ? '관심 스토어에 추가했어요.' : '관심 스토어에서 해제했어요.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _interestSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('관심 스토어를 변경하지 못했어요.')));
    }
  }
}

class _StoreHeroImage extends StatelessWidget {
  const _StoreHeroImage({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: url.isEmpty
            ? const _StoreImageFallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _StoreImageFallback(),
              ),
      ),
    );
  }
}

class _StoreImageFallback extends StatelessWidget {
  const _StoreImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: PopqPalette.forest,
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 76,
          color: PopqPalette.lime,
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.label, required this.available});

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        available ? Icons.check_circle_outline : Icons.cancel_outlined,
        size: 18,
      ),
      label: Text('$label ${available ? '가능' : '불가'}'),
    );
  }
}

String _storeTypeLabel(String storeType) {
  return storeType == 'EVENT_COMMERCE' ? '행사·팝업 판매점' : '일반 매장';
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'PRE_OPEN' => '영업 준비',
    'CLOSED' => '영업 종료',
    _ => status,
  };
}

class _StoreReviewSection extends StatelessWidget {
  const _StoreReviewSection({required this.reviews});

  final Future<List<CustomerReview>> reviews;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerReview>>(
      future: reviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(PopqSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Text('리뷰를 불러오지 못했어요.');
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(PopqSpacing.lg),
              child: Text('아직 등록된 리뷰가 없어요.'),
            ),
          );
        }
        return Column(
          children: [
            for (final review in items)
              Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(review.authorName)),
                      Text(List.filled(review.rating, '★').join()),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.content != null) Text(review.content!),
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
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
