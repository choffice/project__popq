import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../discovery/store_discovery_repository.dart';
import '../discovery/store_section_widgets.dart';
import 'announcement_pinned_badge.dart';
import 'public_announcement_repository.dart';

class PublicAnnouncementListScreen extends StatefulWidget {
  const PublicAnnouncementListScreen({
    required this.storeId,
    required this.repository,
    required this.storeRepository,
    super.key,
  });

  final int storeId;
  final PublicAnnouncementRepository repository;
  final StoreDiscoveryRepository storeRepository;

  @override
  State<PublicAnnouncementListScreen> createState() =>
      _PublicAnnouncementListScreenState();
}

class _PublicAnnouncementListScreenState
    extends State<PublicAnnouncementListScreen> {
  late Future<CustomerStore> _store;
  late Future<List<PublicAnnouncement>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _store = widget.storeRepository.findDetail(widget.storeId);
    _items = widget.repository.findAll(widget.storeId);
  }

  Future<void> _refresh() async {
    setState(_reload);

    try {
      await Future.wait<Object?>(
        <Future<Object?>>[
          _store,
          _items,
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
        title: const Text('공지사항'),
      ),
      body: FutureBuilder<CustomerStore>(
        future: _store,
        builder: (
            BuildContext context,
            AsyncSnapshot<CustomerStore> storeSnap,
            ) {
          return FutureBuilder<List<PublicAnnouncement>>(
            future: _items,
            builder: (
                BuildContext context,
                AsyncSnapshot<List<PublicAnnouncement>> itemSnap,
                ) {
              if (storeSnap.connectionState != ConnectionState.done ||
                  itemSnap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!storeSnap.hasData || itemSnap.hasError) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(_reload);
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text(
                      '공지사항 다시 불러오기',
                    ),
                  ),
                );
              }

              final List<PublicAnnouncement> items =
                  itemSnap.data ?? const <PublicAnnouncement>[];

              final CustomerStore store = storeSnap.requireData;

              return Column(
                children: <Widget>[
                  StoreSectionTopBar(
                    store: store,
                    selected: StoreSection.announcements,
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? RefreshIndicator(
                      onRefresh: _refresh,
                      child: const CustomScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        slivers: <Widget>[
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: PopqEmptyView(
                              icon: Icons.campaign_outlined,
                              title: '등록된 공지사항이 없습니다.',
                              description:
                              '매장의 새로운 소식이 등록되면 '
                                  '이곳에서 확인할 수 있어요.',
                            ),
                          ),
                        ],
                      ),
                    )
                        : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics:
                        const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          top: PopqSpacing.md,
                          bottom: PopqSpacing.lg,
                        ),
                        children: <Widget>[
                          for (final PublicAnnouncement item in items)
                            Card(
                              margin: const EdgeInsets.fromLTRB(
                                PopqSpacing.md,
                                0,
                                PopqSpacing.md,
                                PopqSpacing.sm,
                              ),
                              child: ListTile(
                                leading:
                                item.imageUrl
                                    ?.trim()
                                    .isNotEmpty ==
                                    true
                                    ? SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(
                                      10,
                                    ),
                                    child: Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                          BuildContext context,
                                          Object error,
                                          StackTrace? stackTrace,
                                          ) {
                                        return Container(
                                          alignment:
                                          Alignment.center,
                                          color: Theme.of(
                                            context,
                                          )
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                            Icons
                                                .broken_image_outlined,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                    : null,
                                title: Row(
                                  children: <Widget>[
                                    if (item.pinned) ...<Widget>[
                                      const AnnouncementPinnedBadge(),
                                      const SizedBox(
                                        width: PopqSpacing.xs,
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        item.title,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  _formatDate(
                                    item.publishedAt,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () {
                                  context.push(
                                    '${CustomerRoutes.stores}/'
                                        '${widget.storeId}'
                                        '/announcements/'
                                        '${item.announcementId}',
                                  );
                                },
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

class PublicAnnouncementDetailScreen extends StatelessWidget {
  const PublicAnnouncementDetailScreen({
    required this.storeId,
    required this.announcementId,
    required this.repository,
    super.key,
  });

  final int storeId;
  final int announcementId;
  final PublicAnnouncementRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const StoreBackButton(),
        title: const Text('공지사항'),
      ),
      body: FutureBuilder<PublicAnnouncement>(
        future: repository.findOne(
          storeId,
          announcementId,
        ),
        builder: (
            BuildContext context,
            AsyncSnapshot<PublicAnnouncement> snapshot,
            ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                '공지사항을 불러오지 못했습니다.',
              ),
            );
          }

          final PublicAnnouncement item = snapshot.requireData;

          return ListView(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (item.pinned) ...<Widget>[
                    const Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                      ),
                      child: AnnouncementPinnedBadge(),
                    ),
                    const SizedBox(
                      width: PopqSpacing.sm,
                    ),
                  ],
                  Expanded(
                    child: Text(
                      item.title,
                      style:
                      Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                _formatDate(
                  item.publishedAt,
                ),
              ),
              if (item.imageUrl?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(
                  height: PopqSpacing.lg,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    16,
                  ),
                  child: Image.network(
                    item.imageUrl!,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                        ) {
                      return Container(
                        width: double.infinity,
                        height: 160,
                        alignment: Alignment.center,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.broken_image_outlined,
                              size: 36,
                            ),
                            SizedBox(
                              height: 6,
                            ),
                            Text(
                              '이미지를 불러오지 못했습니다.',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const Divider(
                height: PopqSpacing.xl,
              ),
              SelectableText(
                item.content,
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '';
  }

  final DateTime local = value.toLocal();

  final String month =
  local.month.toString().padLeft(2, '0');

  final String day =
  local.day.toString().padLeft(2, '0');

  return '${local.year}.$month.$day';
}