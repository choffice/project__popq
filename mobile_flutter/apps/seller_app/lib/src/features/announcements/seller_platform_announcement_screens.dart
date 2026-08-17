import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';

class SellerPlatformAnnouncementListScreen extends StatefulWidget {
  const SellerPlatformAnnouncementListScreen({
    required this.repository,
    super.key,
  });

  final PlatformAnnouncementRepository repository;

  @override
  State<SellerPlatformAnnouncementListScreen> createState() =>
      _SellerPlatformAnnouncementListScreenState();
}

class _SellerPlatformAnnouncementListScreenState
    extends State<SellerPlatformAnnouncementListScreen> {
  late Future<List<PlatformAnnouncement>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = widget.repository.findAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<PlatformAnnouncement>>(
        future: _items,
        builder: (
            BuildContext context,
            AsyncSnapshot<List<PlatformAnnouncement>> snapshot,
            ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(
              message: '공지사항을 불러오고 있어요.',
            );
          }

          if (snapshot.hasError) {
            return PopqErrorView(
              message: '공지사항을 불러오지 못했어요.',
              onRetry: () {
                setState(_reload);
              },
            );
          }

          final List<PlatformAnnouncement> items =
              snapshot.data ?? const <PlatformAnnouncement>[];

          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
              },
              child: const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: PopqEmptyView(
                      icon: Icons.campaign_outlined,
                      title: '등록된 공지사항이 없습니다.',
                      description:
                      '새로운 POPQ 소식이 등록되면 '
                          '이곳에서 확인할 수 있어요.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(
                PopqSpacing.md,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) {
                return const SizedBox(
                  height: PopqSpacing.sm,
                );
              },
              itemBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                final PlatformAnnouncement item = items[index];

                return Card(
                  child: ListTile(
                    key: Key(
                      'seller-platform-announcement-'
                          '${item.platformAnnouncementId}',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: PopqSpacing.md,
                      vertical: PopqSpacing.sm,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.campaign_outlined,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(
                        top: PopqSpacing.xs,
                      ),
                      child: Text(
                        '${_formatDate(item.displayDate)}\n'
                            '${item.content}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      context.push(
                        SellerRoutes.platformAnnouncementDetail(
                          item.platformAnnouncementId,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SellerPlatformAnnouncementDetailScreen
    extends StatelessWidget {
  const SellerPlatformAnnouncementDetailScreen({
    required this.platformAnnouncementId,
    required this.repository,
    super.key,
  });

  final int platformAnnouncementId;
  final PlatformAnnouncementRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        centerTitle: true,
      ),
      body: FutureBuilder<PlatformAnnouncement>(
        future: repository.findOne(
          platformAnnouncementId,
        ),
        builder: (
            BuildContext context,
            AsyncSnapshot<PlatformAnnouncement> snapshot,
            ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(
              message: '공지사항을 불러오고 있어요.',
            );
          }

          if (!snapshot.hasData) {
            return const PopqErrorView(
              message: '공지사항을 찾을 수 없어요.',
            );
          }

          final PlatformAnnouncement item = snapshot.requireData;

          return ListView(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: <Widget>[
              Text(
                item.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                _formatDate(
                  item.displayDate,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(
                height: PopqSpacing.xl,
              ),
              SelectableText(
                item.content,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  height: 1.65,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();

  final String month =
  local.month.toString().padLeft(2, '0');

  final String day =
  local.day.toString().padLeft(2, '0');

  return '${local.year}.$month.$day';
}