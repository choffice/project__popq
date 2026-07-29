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
        title: const Text('스토어 상세'),
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
          return ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: PopqPalette.forest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 76,
                  color: PopqPalette.lime,
                ),
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
                  const Chip(label: Text('영업 중')),
                ],
              ),
              if (store.description != null) ...[
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  store.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (store.address != null) ...[
                const SizedBox(height: PopqSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_rounded),
                  title: const Text('위치'),
                  subtitle: Text(store.address!),
                ),
              ],
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
                  subtitle: review.content == null
                      ? null
                      : Text(review.content!),
                ),
              ),
          ],
        );
      },
    );
  }
}
