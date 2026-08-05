import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../announcements/seller_announcement_repository.dart';
import '../announcements/seller_announcement_screen.dart';
import '../home/seller_analytics_repository.dart';
import '../products/seller_product_list_screen.dart';
import '../products/seller_product_repository.dart';
import '../sales/seller_sales_screen.dart';
import '../stores/seller_store_edit_screen.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

class SellerOperationScreen extends StatefulWidget {
  const SellerOperationScreen({
    required this.storeRepository,
    required this.announcementRepository,
    required this.productRepository,
    required this.analyticsRepository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerAnnouncementRepository announcementRepository;
  final SellerProductRepository productRepository;
  final SellerAnalyticsRepository analyticsRepository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerOperationScreen> createState() =>
      _SellerOperationScreenState();
}

class _SellerOperationScreenState extends State<SellerOperationScreen> {
  var _section = 0;

  SellerStore? _store;
  Object? _error;

  var _loading = true;
  var _changingStatus = false;

  int get _storeId => widget.selectionController.selectedStoreId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(
        message: '선택한 사업장 운영정보를 불러오고 있어요.',
      );
    }

    if (_error != null || _store == null) {
      return PopqErrorView(
        message: '사업장 운영정보를 불러오지 못했습니다.',
        onRetry: _load,
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(PopqSpacing.sm),
            children: [
              _sectionChip(
                0,
                '운영정보',
                Icons.storefront_outlined,
              ),
              _sectionChip(
                1,
                '공지사항',
                Icons.campaign_outlined,
              ),
              _sectionChip(
                2,
                '메뉴 관리',
                Icons.restaurant_menu_outlined,
              ),
              _sectionChip(
                3,
                '매출',
                Icons.query_stats_outlined,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            0 => _operationInfo(),
            1 => SellerAnnouncementScreen(
              storeId: _storeId,
              canManage:
              _store!.myRole == 'OWNER' ||
                  _store!.myRole == 'MANAGER',
              repository: widget.announcementRepository,
            ),
            2 => SellerProductListScreen(
              repository: widget.productRepository,
              selectionController: widget.selectionController,
            ),
            _ => SellerSalesScreen(
              storeRepository: widget.storeRepository,
              analyticsRepository: widget.analyticsRepository,
              selectionController: widget.selectionController,
            ),
          },
        ),
      ],
    );
  }

  Widget _sectionChip(
      int index,
      String label,
      IconData icon,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _section == index;

    return Padding(
      padding: const EdgeInsets.only(
        right: PopqSpacing.xs,
      ),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        label: Text(label),
        selected: selected,

        // 선택했을 때 아이콘 자리에 나타나는 체크 표시 제거
        showCheckmark: false,

        selectedColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surface,
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
        labelStyle: TextStyle(
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
          fontWeight: selected
              ? FontWeight.w800
              : FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() {
            _section = index;
          });
        },
      ),
    );
  }

  Widget _operationInfo() {
    final store = _store!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canManage =
        store.myRole == 'OWNER' ||
            store.myRole == 'MANAGER';

    return ListView(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          decoration: BoxDecoration(
            color: colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현재 선택된 사업장',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: PopqSpacing.xs),
              Text(
                store.name,
                style: TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: PopqSpacing.sm),
              Text(
                '${_typeLabel(store.storeType)} · '
                    '${_roleLabel(store.myRole)}',
                style: TextStyle(
                  color: colorScheme.onInverseSurface.withValues(
                    alpha: 0.75,
                  ),
                ),
              ),
              if (store.representativeCategory?.isNotEmpty == true) ...[
                const SizedBox(height: PopqSpacing.sm),
                Chip(
                  avatar: const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 18,
                  ),
                  label: Text(
                    store.representativeCategory!,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: PopqSpacing.lg),

        Text(
          '영업 상태 관리',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'PRE_OPEN',
              label: Text('영업 준비'),
            ),
            ButtonSegment(
              value: 'OPEN',
              label: Text('영업 중'),
            ),
            ButtonSegment(
              value: 'CLOSED',
              label: Text('영업 종료'),
            ),
          ],
          selected: {
            store.businessStatus,
          },
          onSelectionChanged: !canManage || _changingStatus
              ? null
              : (selection) {
            _changeStatus(selection.single);
          },
        ),

        if (!canManage)
          const Padding(
            padding: EdgeInsets.only(
              top: PopqSpacing.sm,
            ),
            child: Text(
              'OWNER 또는 MANAGER만 영업 상태를 변경할 수 있습니다.',
            ),
          ),

        if (_changingStatus)
          const Padding(
            padding: EdgeInsets.only(
              top: PopqSpacing.sm,
            ),
            child: LinearProgressIndicator(),
          ),

        const SizedBox(height: PopqSpacing.lg),

        Text(
          '사업장 기본 정보',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                ),
                title: const Text('내 권한'),
                trailing: Text(
                  _roleLabel(store.myRole),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                ),
                title: const Text('사업장 상태'),
                trailing: Text(
                  store.status == 'ACTIVE'
                      ? '활성'
                      : store.status,
                ),
              ),
              if (store.representativeCategory?.isNotEmpty == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.category_outlined,
                  ),
                  title: const Text('대표 카테고리'),
                  subtitle: Text(
                    store.representativeCategory!,
                  ),
                ),
              ],
              if (store.description?.isNotEmpty == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                  ),
                  title: const Text('설명'),
                  subtitle: Text(
                    store.description!,
                  ),
                ),
              ],
              if (store.address?.isNotEmpty == true ||
                  store.detailAddress?.isNotEmpty == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                  ),
                  title: const Text('주소'),
                  subtitle: Text(
                    _fullAddress(store),
                  ),
                ),
              ],
              if (store.phone?.isNotEmpty == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.phone_outlined,
                  ),
                  title: const Text('연락처'),
                  subtitle: Text(
                    store.phone!,
                  ),
                ),
              ],
              if (store.imageUrl?.isNotEmpty == true) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.image_outlined,
                  ),
                  title: const Text('대표 이미지 URL'),
                  subtitle: Text(
                    store.imageUrl!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (store.latitude != null &&
                  store.longitude != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.my_location_outlined,
                  ),
                  title: const Text('좌표'),
                  subtitle: Text(
                    '${store.latitude}, ${store.longitude}',
                  ),
                ),
              ],
              if (store.tags.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.sell_outlined,
                  ),
                  title: const Text('검색 키워드'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(
                      top: PopqSpacing.xs,
                    ),
                    child: Wrap(
                      spacing: PopqSpacing.xs,
                      runSpacing: PopqSpacing.xs,
                      children: store.tags
                          .map(
                            (tag) => Chip(
                          label: Text('#$tag'),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: PopqSpacing.lg),

        Text(
          '영업 정보',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.schedule_outlined,
                ),
                title: const Text('영업시간'),
                subtitle: Text(
                  _businessHoursLabel(store),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.event_busy_outlined,
                ),
                title: const Text('정기 휴무일'),
                subtitle: Text(
                  _closedDaysLabel(
                    store.closedDays,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: PopqSpacing.lg),

        Text(
          '주문 운영 설정',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        Card(
          child: Column(
            children: [
              _policyTile(
                icon: Icons.shopping_bag_outlined,
                title: '포장',
                enabled: store.takeoutAvailable,
              ),
              const Divider(height: 1),
              _policyTile(
                icon: Icons.table_restaurant_outlined,
                title: '매장 식사',
                enabled: store.dineInAvailable,
              ),
              const Divider(height: 1),
              _policyTile(
                icon: Icons.receipt_long_outlined,
                title: '주문 접수',
                enabled: store.orderAcceptingEnabled,
              ),
            ],
          ),
        ),

        const SizedBox(height: PopqSpacing.md),

        FilledButton.icon(
          key: const Key('edit-store'),
          onPressed: canManage ? _editStore : null,
          icon: const Icon(
            Icons.edit_outlined,
          ),
          label: const Text(
            '사업장 정보 수정',
          ),
        ),
      ],
    );
  }

  Widget _policyTile({
    required IconData icon,
    required String title,
    required bool enabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: enabled
                ? Colors.green
                : colorScheme.error,
          ),
          const SizedBox(width: PopqSpacing.xs),
          Text(
            enabled ? '가능' : '불가',
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = await widget.storeRepository.findOne(
        _storeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(String status) async {
    if (status == _store?.businessStatus) {
      return;
    }

    setState(() {
      _changingStatus = true;
    });

    try {
      final updated =
      await widget.storeRepository.changeBusinessStatus(
        _storeId,
        status,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _store = updated;
        _changingStatus = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingStatus = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '영업 상태를 변경하지 못했습니다.',
            ),
          ),
        );
    }
  }

  Future<void> _editStore() async {
    final current = _store;

    if (current == null) {
      return;
    }

    final updated = await Navigator.of(context).push<SellerStore>(
      MaterialPageRoute<SellerStore>(
        builder: (context) {
          return SellerStoreEditScreen(
            repository: widget.storeRepository,
            store: current,
          );
        },
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _store = updated;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '사업장 정보를 수정했습니다.',
          ),
        ),
      );
  }
}

String _typeLabel(String type) {
  return type == 'EVENT_COMMERCE'
      ? '행사·팝업 판매점'
      : '일반 매장';
}

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => '소유자',
    'MANAGER' => '매니저',
    'STAFF' => '스태프',
    _ => role,
  };
}

String _fullAddress(SellerStore store) {
  return [
    store.address,
    store.detailAddress,
  ]
      .where(
        (value) =>
    value != null &&
        value.trim().isNotEmpty,
  )
      .join(' ');
}

String _businessHoursLabel(SellerStore store) {
  final openTime = _displayTime(
    store.openTime,
  );

  final closeTime = _displayTime(
    store.closeTime,
  );

  if (openTime == null || closeTime == null) {
    return '영업시간 미등록';
  }

  return '$openTime ~ $closeTime';
}

String? _displayTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final parts = value.split(':');

  if (parts.length < 2) {
    return value;
  }

  return '${parts[0].padLeft(2, '0')}:'
      '${parts[1].padLeft(2, '0')}';
}

String _closedDaysLabel(
    List<String> closedDays,
    ) {
  if (closedDays.isEmpty) {
    return '정기 휴무 없음';
  }

  return closedDays
      .map(_dayLabel)
      .join(', ');
}

String _dayLabel(String day) {
  return switch (day) {
    'MONDAY' => '월요일',
    'TUESDAY' => '화요일',
    'WEDNESDAY' => '수요일',
    'THURSDAY' => '목요일',
    'FRIDAY' => '금요일',
    'SATURDAY' => '토요일',
    'SUNDAY' => '일요일',
    _ => day,
  };
}
