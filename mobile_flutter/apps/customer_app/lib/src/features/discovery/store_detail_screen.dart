import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import '../cart/customer_cart_action.dart';
import '../announcements/public_announcement_repository.dart';
import '../announcements/announcement_pinned_badge.dart';
import '../catalog/catalog_repository.dart';
import '../profile/customer_engagement_repository.dart';
import 'store_discovery_repository.dart';
import 'store_section_widgets.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({
    required this.storeId,
    required this.repository,
    required this.engagementRepository,
    required this.sessionController,
    required this.catalogRepository,
    required this.announcementRepository,
    required this.cartController,
    super.key,
  });

  final int storeId;
  final StoreDiscoveryRepository repository;
  final CustomerEngagementRepository engagementRepository;
  final SessionController sessionController;
  final CatalogRepository catalogRepository;
  final PublicAnnouncementRepository announcementRepository;
  final CartController cartController;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late Future<CustomerStore> _store;
  late Future<List<CustomerReview>> _reviews;
  late Future<List<CatalogProduct>> _products;
  late Future<List<PublicAnnouncement>> _announcements;
  bool? _interested;
  var _interestSaving = false;

  @override
  void initState() {
    super.initState();
    _store = widget.repository.findDetail(widget.storeId);
    _reviews = widget.engagementRepository.findPublicReviews(widget.storeId);
    _products = widget.catalogRepository.findProducts(widget.storeId);
    _announcements = widget.announcementRepository.findAll(widget.storeId);
    if (widget.sessionController.isSignedIn) {
      _loadInterest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const StoreBackButton(),
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
          CustomerCartAction(
            controller: widget.cartController,
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
          final orderPaused = !store.orderAcceptingEnabled;
          final String eventName = store.eventName?.trim() ?? '';
          return Column(
            children: <Widget>[
              StoreSectionTopBar(store: store, selected: StoreSection.info),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(PopqSpacing.lg),
                  children: [
                    _StoreHeroImage(imageUrl: store.imageUrl, height: 180),
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
                        Chip(
                          label: Text(
                            _businessStatusLabel(store.businessStatus),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PopqSpacing.sm),
                    Wrap(
                      spacing: PopqSpacing.sm,
                      runSpacing: PopqSpacing.xs,
                      children: [
                        Chip(label: Text(_storeTypeLabel(store.storeType))),
                        if (store.representativeCategory?.trim().isNotEmpty ==
                            true)
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
                    if (store.storeType == 'EVENT_COMMERCE' &&
                        eventName.isNotEmpty) ...[
                      const SizedBox(height: PopqSpacing.sm),
                      ListTile(
                        key: const Key('store-detail-event-name'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.celebration_outlined),
                        title: const Text('행사명'),
                        subtitle: Text(eventName),
                      ),
                    ],
                    if (store.operationStartDate != null ||
                        store.operationEndDate != null) ...[
                      const SizedBox(height: PopqSpacing.sm),
                      ListTile(
                        key: const Key('store-detail-operation-period'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: Text(
                          store.storeType == 'EVENT_COMMERCE' ? '행사 기간' : '오픈일',
                        ),
                        subtitle: Text(_operationPeriodLabel(store)),
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
                                trailing: const Icon(Icons.call_outlined),
                                onTap: () => _callPhone(store.phone!),
                              ),
                            ],
                            if (store.fullAddress.isNotEmpty ||
                                store.phone?.trim().isNotEmpty == true)
                              const Divider(height: 1),
                            ExpansionTile(
                              leading: const Icon(Icons.schedule_outlined),
                              title: const Text('영업시간'),
                              subtitle: Text(
                                _todayHoursSubtitle(schedule.todayLabel()),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                PopqSpacing.lg,
                                0,
                                PopqSpacing.lg,
                                PopqSpacing.md,
                              ),
                              children: schedule
                                  .summaryLines()
                                  .map(
                                    (line) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: PopqSpacing.xs,
                                        ),
                                        child: Text(line),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                            const Divider(height: 1),
                            const ListTile(
                              leading: Icon(Icons.free_breakfast_outlined),
                              title: Text('브레이크 타임'),
                              subtitle: Text('등록된 브레이크 타임 정보가 없습니다.'),
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
                                  available:
                                      store.businessStatus == 'OPEN' &&
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
                    _MenuPreview(products: _products, storeId: store.storeId),
                    const SizedBox(height: PopqSpacing.xl),
                    _LatestAnnouncementPreview(
                      announcements: _announcements,
                      storeId: store.storeId,
                    ),
                    const SizedBox(height: PopqSpacing.xl),
                    FilledButton.icon(
                      onPressed: () {
                        context.push(
                          storeSectionPath(
                            store.storeId,
                            StoreSection.products,
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('상품 보기'),
                    ),
                    const SizedBox(height: PopqSpacing.xl),
                    Text(
                      '고객 리뷰',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: PopqSpacing.sm),
                    _StoreReviewSection(reviews: _reviews),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _callPhone(String rawPhone) async {
    final String phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: phone);
    try {
      final bool available = await canLaunchUrl(uri);
      if (!available || !await launchUrl(uri)) {
        throw StateError('phone launch unavailable');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('전화 앱을 열지 못했습니다.')));
    }
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
          content: Text(interested ? '관심 스토어에 추가했어요.' : '관심 스토어에서 해제했어요.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _interestSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('관심 스토어를 변경하지 못했어요.')));
    }
  }
}

class _MenuPreview extends StatelessWidget {
  const _MenuPreview({required this.products, required this.storeId});

  final Future<List<CatalogProduct>> products;
  final int storeId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '대표 메뉴',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () =>
                  openStoreSection(context, storeId, StoreSection.products),
              child: const Text('전체 보기'),
            ),
          ],
        ),
        SizedBox(
          height: 190,
          child: FutureBuilder<List<CatalogProduct>>(
            future: products,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<CatalogProduct>> snapshot,
                ) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('메뉴 미리보기를 불러오지 못했습니다.'),
                    );
                  }
                  final List<CatalogProduct> items = (snapshot.data ?? const [])
                      .where(
                        (CatalogProduct item) => item.availableForCustomerApp,
                      )
                      .take(5)
                      .toList(growable: false);
                  if (items.isEmpty) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('공개된 메뉴가 없습니다.'),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: PopqSpacing.sm),
                    itemBuilder: (BuildContext context, int index) {
                      final CatalogProduct item = items[index];
                      return SizedBox(
                        width: 132,
                        child: Card(
                          child: InkWell(
                            onTap: item.soldOut
                                ? null
                                : () => context.push(
                                    '${CustomerRoutes.stores}/$storeId'
                                    '/products/${item.productId}',
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.all(PopqSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 72,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child:
                                          item.imageUrl?.trim().isNotEmpty ==
                                              true
                                          ? Image.network(
                                              item.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const ColoredBox(
                                                    color: PopqPalette.forest,
                                                    child: Icon(
                                                      Icons
                                                          .restaurant_menu_rounded,
                                                      color: PopqPalette.lime,
                                                    ),
                                                  ),
                                            )
                                          : const ColoredBox(
                                              color: PopqPalette.forest,
                                              child: Icon(
                                                Icons.restaurant_menu_rounded,
                                                color: PopqPalette.lime,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: PopqSpacing.xs),
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(item.categoryName),
                                  Text(
                                    item.soldOut
                                        ? '${item.basePrice}원 · 품절'
                                        : '${item.basePrice}원',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
          ),
        ),
      ],
    );
  }
}

class _LatestAnnouncementPreview extends StatelessWidget {
  const _LatestAnnouncementPreview({
    required this.announcements,
    required this.storeId,
  });

  final Future<List<PublicAnnouncement>> announcements;
  final int storeId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '공지사항',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => openStoreSection(
                context,
                storeId,
                StoreSection.announcements,
              ),
              child: const Text('전체 보기'),
            ),
          ],
        ),
        FutureBuilder<List<PublicAnnouncement>>(
          future: announcements,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<PublicAnnouncement>> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return const Text('최신 공지사항을 불러오지 못했습니다.');
                }
                final List<PublicAnnouncement> items =
                    snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const Text('등록된 공지사항이 없습니다.');
                }
                final PublicAnnouncement latest = items.first;
                return Card(
                  child: ListTile(
                    leading: latest.imageUrl?.trim().isNotEmpty == true
                        ? SizedBox(
                            width: 56,
                            height: 56,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                latest.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return Container(
                                        alignment: Alignment.center,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        child: const Icon(
                                          Icons.campaign_outlined,
                                        ),
                                      );
                                    },
                              ),
                            ),
                          )
                        : const Icon(Icons.campaign_outlined),
                    title: Row(
                      children: <Widget>[
                        if (latest.pinned) ...<Widget>[
                          const AnnouncementPinnedBadge(),
                          const SizedBox(width: PopqSpacing.xs),
                        ],
                        Expanded(child: Text(latest.title)),
                      ],
                    ),
                    subtitle: Text(_announcementDateLabel(latest.publishedAt)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(
                      '${CustomerRoutes.stores}/$storeId'
                      '/announcements/${latest.announcementId}',
                    ),
                  ),
                );
              },
        ),
      ],
    );
  }
}

String _announcementDateLabel(DateTime? value) {
  if (value == null) return '';
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
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
                  '현재 주문 접수가 잠시 중단되었어요.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '상품은 둘러볼 수 있지만 새로운 주문은 접수 재개 후 진행할 수 있어요.',
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
    'PRE_OPEN' => '준비중',
    _ => status,
  };
}

String _operationPeriodLabel(CustomerStore store) {
  final String? start = _formatStoreDate(store.operationStartDate);
  final String? end = _formatStoreDate(store.operationEndDate);
  if (start != null && end != null) return '$start ~ $end';
  if (start != null)
    return store.storeType == 'EVENT_COMMERCE' ? '$start부터' : '$start 영업 시작';
  return '$end까지';
}

String _todayHoursSubtitle(String label) {
  final String value = label.startsWith('오늘 ')
      ? label.substring('오늘 '.length)
      : label;
  return '오늘 · $value';
}

String? _formatStoreDate(DateTime? value) {
  if (value == null) return null;
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
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
        final average =
            items
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
                      '전체 평점 ${average.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text('리뷰 ${items.length}개'),
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
                      Text(List.filled(review.rating, '★').join()),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.content != null) Text(review.content!),
                      if (review.imageUrl != null) ...[
                        const SizedBox(height: PopqSpacing.sm),
                        _ReviewImage(imageUrl: review.imageUrl!),
                      ],
                      if (review.sellerReply?.isNotEmpty ?? false) ...[
                        const SizedBox(height: PopqSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(PopqSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
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

class _ReviewImage extends StatelessWidget {
  const _ReviewImage({required this.imageUrl});

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
