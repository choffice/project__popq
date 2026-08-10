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
        title: const Text('留ㅼ옣 ?곸꽭'),
        actions: [
          IconButton(
            tooltip: _interested == true ? '愿???ㅽ넗???댁젣' : '愿???ㅽ넗???깅줉',
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
            return const PopqLoadingView(message: '?ㅽ넗???뺣낫瑜?遺덈윭?ㅺ퀬 ?덉뼱??');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '?ㅽ넗???곸꽭 ?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?댁슂.',
              onRetry: () => setState(() {
                _store = widget.repository.findDetail(widget.storeId);
              }),
            );
          }
          final store = snapshot.requireData;
          final schedule = store.resolvedSchedule;
          final orderPaused = !store.orderAcceptingEnabled;
          return ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              _StoreHeroImage(
                imageUrl: store.imageUrl,
                height: 180,
              ),
              const SizedBox(height: PopqSpacing.lg),
              if (orderPaused) ...[
                const _OrderPausedBanner(),
                const SizedBox(height: PopqSpacing.md),
              ],
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
                          title: const Text('?꾩튂'),
                          subtitle: Text(store.fullAddress),
                        ),
                      if (store.phone?.trim().isNotEmpty == true) ...[
                        if (store.fullAddress.isNotEmpty)
                          const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.phone_outlined),
                          title: const Text('?꾪솕踰덊샇'),
                          subtitle: Text(store.phone!),
                        ),
                      ],
                      if (store.fullAddress.isNotEmpty ||
                          store.phone?.trim().isNotEmpty == true)
                        const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.today_outlined),
                        title: const Text('?ㅻ뒛 ?곸뾽?쒓컙'),
                        subtitle: Text(schedule.todayLabel()),
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        leading: const Icon(Icons.schedule_outlined),
                        title: const Text('?꾩껜 ?곸뾽?쒓컙'),
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
                        '?댁슜 ?덈궡',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: PopqSpacing.sm),
                      Wrap(
                        spacing: PopqSpacing.sm,
                        runSpacing: PopqSpacing.sm,
                        children: [
                          _AvailabilityChip(
                            label: '?ъ옣',
                            available: store.takeoutAvailable,
                          ),
                          _AvailabilityChip(
                            label: '留ㅼ옣 ?앹궗',
                            available: store.dineInAvailable,
                          ),
                          _AvailabilityChip(
                            label: '二쇰Ц ?묒닔',
                            available: store.businessStatus == 'OPEN' &&
                                store.orderAcceptingEnabled,
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
                label: const Text('?곹뭹 蹂닿린'),
              ),
              const SizedBox(height: PopqSpacing.xl),
              Text('怨좉컼 由щ럭', style: Theme.of(context).textTheme.titleLarge),
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
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(interested ? '愿???ㅽ넗?댁뿉 異붽??덉뼱??' : '愿???ㅽ넗?댁뿉???댁젣?덉뼱??'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _interestSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('愿???ㅽ넗?대? 蹂寃쏀븯吏 紐삵뻽?댁슂.')));
    }
  }
}


class _OrderPausedBanner extends StatelessWidget {
  const _OrderPausedBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: PopqSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '?꾩옱 二쇰Ц ?묒닔媛 ?좎떆 以묐떒?섏뿀?댁슂.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '?곹뭹? ?섎윭蹂????덉?留??덈줈??二쇰Ц? ?묒닔 ?ш컻 ??吏꾪뻾?????덉뼱??',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      label: Text('$label ${available ? '媛?? : '遺덇?'}'),
    );
  }
}

String _storeTypeLabel(String storeType) {
  return storeType == 'EVENT_COMMERCE' ? '?됱궗쨌?앹뾽 ?먮ℓ?? : '?쇰컲 留ㅼ옣';
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '?곸뾽 以?,
    'PRE_OPEN' => '?곸뾽 以鍮?,
    'CLOSED' => '?곸뾽 醫낅즺',
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
          return const Text('由щ럭瑜?遺덈윭?ㅼ? 紐삵뻽?댁슂.');
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(PopqSpacing.lg),
              child: Text('?꾩쭅 ?깅줉??由щ럭媛 ?놁뼱??'),
            ),
          );
        }
        final average = items
                .map((review) => review.rating)
                .reduce((left, right) => left + right) /
            items.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(PopqSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
                    const SizedBox(width: PopqSpacing.xs),
                    Text(
                      '?꾩껜 ?됱젏 ${average.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text('由щ럭 ${items.length}媛?),
                  ],
                ),
              ),
            ),
            for (final review in items)
              Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(review.authorName)),
                      Text(List.filled(review.rating, '??).join()),
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
                          child: Text('?ъ옣???듦?\n${review.sellerReply!}'),
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

