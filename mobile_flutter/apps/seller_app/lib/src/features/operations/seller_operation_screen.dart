import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../announcements/seller_announcement_repository.dart';
import '../announcements/seller_announcement_screen.dart';
import '../home/seller_analytics_repository.dart';
import '../products/seller_product_list_screen.dart';
import '../products/seller_product_repository.dart';
import '../sales/seller_sales_screen.dart';
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
  var _savingStore = false;

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
          onPressed: canManage && !_savingStore
              ? _editStore
              : null,
          icon: _savingStore
              ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Icon(
            Icons.edit_outlined,
          ),
          label: Text(
            _savingStore
                ? '사업장 정보 저장 중...'
                : '사업장 정보 수정',
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

    if (current == null || _savingStore) {
      return;
    }

    final value = await showDialog<_StoreEditValue>(
      context: context,
      builder: (dialogContext) {
        return _StoreEditDialog(
          store: current,
        );
      },
    );

    if (value == null || !mounted) {
      return;
    }

    setState(() {
      _savingStore = true;
    });

    try {
      final updated = await widget.storeRepository.update(
        _storeId,
        name: value.name,
        description: value.description,
        address: value.address,
        detailAddress: value.detailAddress,
        representativeCategory:
        value.representativeCategory,
        imageUrl: value.imageUrl,
        phone: value.phone,
        latitude: value.latitude,
        longitude: value.longitude,
        openTime: value.openTime,
        closeTime: value.closeTime,
        closedDays: value.closedDays,
        takeoutAvailable: value.takeoutAvailable,
        dineInAvailable: value.dineInAvailable,
        orderAcceptingEnabled:
        value.orderAcceptingEnabled,
        tags: value.tags,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _store = updated;
        _savingStore = false;
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingStore = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '사업장 정보를 수정하지 못했습니다.',
            ),
          ),
        );
    }
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

class _StoreEditValue {
  const _StoreEditValue({
    required this.name,
    required this.description,
    required this.address,
    required this.detailAddress,
    required this.representativeCategory,
    required this.imageUrl,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.openTime,
    required this.closeTime,
    required this.closedDays,
    required this.takeoutAvailable,
    required this.dineInAvailable,
    required this.orderAcceptingEnabled,
    required this.tags,
  });

  final String name;
  final String? description;
  final String address;
  final String detailAddress;
  final String representativeCategory;
  final String? imageUrl;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String openTime;
  final String closeTime;
  final List<String> closedDays;
  final bool takeoutAvailable;
  final bool dineInAvailable;
  final bool orderAcceptingEnabled;
  final List<String> tags;
}

class _StoreEditDialog extends StatefulWidget {
  const _StoreEditDialog({
    required this.store,
  });

  final SellerStore store;

  @override
  State<_StoreEditDialog> createState() =>
      _StoreEditDialogState();
}

class _StoreEditDialogState
    extends State<_StoreEditDialog> {
  static const _categories = [
    '카페',
    '디저트',
    '베이커리',
    '한식',
    '중식',
    '일식',
    '양식',
    '분식',
    '치킨',
    '피자',
    '패스트푸드',
    '주점',
    '푸드트럭',
    '팝업·행사',
    '기타',
  ];

  static const _days = <String, String>{
    'MONDAY': '월',
    'TUESDAY': '화',
    'WEDNESDAY': '수',
    'THURSDAY': '목',
    'FRIDAY': '금',
    'SATURDAY': '토',
    'SUNDAY': '일',
  };

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _detailAddressController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _phoneController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _tagsController;

  String? _representativeCategory;

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  late final Set<String> _closedDays;

  late bool _takeoutAvailable;
  late bool _dineInAvailable;
  late bool _orderAcceptingEnabled;

  String? _error;

  @override
  void initState() {
    super.initState();

    final store = widget.store;

    _nameController = TextEditingController(
      text: store.name,
    );

    _descriptionController = TextEditingController(
      text: store.description,
    );

    _addressController = TextEditingController(
      text: store.address,
    );

    _detailAddressController = TextEditingController(
      text: store.detailAddress,
    );

    _imageUrlController = TextEditingController(
      text: store.imageUrl,
    );

    _phoneController = TextEditingController(
      text: store.phone,
    );

    _latitudeController = TextEditingController(
      text: store.latitude?.toString() ?? '',
    );

    _longitudeController = TextEditingController(
      text: store.longitude?.toString() ?? '',
    );

    _tagsController = TextEditingController(
      text: store.tags.join(', '),
    );

    _representativeCategory =
        store.representativeCategory;

    if (_representativeCategory != null &&
        !_categories.contains(_representativeCategory)) {
      _representativeCategory = '기타';
    }

    _openTime = _parseTime(
      store.openTime,
    );

    _closeTime = _parseTime(
      store.closeTime,
    );

    _closedDays = {
      ...store.closedDays,
    };

    _takeoutAvailable =
        store.takeoutAvailable;

    _dineInAvailable =
        store.dineInAvailable;

    _orderAcceptingEnabled =
        store.orderAcceptingEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _imageUrlController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _tagsController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '사업장 정보 수정',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key(
                  'edit-store-name',
                ),
                controller: _nameController,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: '사업장 이름',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue:
                _representativeCategory,
                decoration: const InputDecoration(
                  labelText: '대표 카테고리',
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _representativeCategory = value;
                  });
                },
              ),
              const SizedBox(height: PopqSpacing.sm),
              TextField(
                controller:
                _descriptionController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '설명',
                ),
              ),
              TextField(
                key: const Key(
                  'edit-store-address',
                ),
                controller: _addressController,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: '주소',
                ),
              ),
              TextField(
                controller:
                _detailAddressController,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: '상세 주소',
                ),
              ),
              TextField(
                controller: _phoneController,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '사업장 연락처',
                ),
              ),
              TextField(
                controller: _imageUrlController,
                maxLength: 1000,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '대표 이미지 URL',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _selectTime(
                          isOpenTime: true,
                        );
                      },
                      icon: const Icon(
                        Icons.schedule_rounded,
                      ),
                      label: Text(
                        _openTime == null
                            ? '영업 시작'
                            : _formatTime(_openTime!),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: PopqSpacing.sm,
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _selectTime(
                          isOpenTime: false,
                        );
                      },
                      icon: const Icon(
                        Icons.schedule_rounded,
                      ),
                      label: Text(
                        _closeTime == null
                            ? '영업 종료'
                            : _formatTime(_closeTime!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PopqSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '정기 휴무일',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall,
                ),
              ),
              const SizedBox(height: PopqSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: PopqSpacing.xs,
                  runSpacing: PopqSpacing.xs,
                  children: _days.entries.map((entry) {
                    final selected =
                    _closedDays.contains(entry.key);

                    return FilterChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _closedDays.add(entry.key);
                          } else {
                            _closedDays.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: PopqSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '포장 가능',
                ),
                value: _takeoutAvailable,
                onChanged: (value) {
                  setState(() {
                    _takeoutAvailable = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '매장 식사 가능',
                ),
                value: _dineInAvailable,
                onChanged: (value) {
                  setState(() {
                    _dineInAvailable = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '주문 접수 가능',
                ),
                value: _orderAcceptingEnabled,
                onChanged: (value) {
                  setState(() {
                    _orderAcceptingEnabled = value;
                  });
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latitudeController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '위도',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: PopqSpacing.sm,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _longitudeController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '경도',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                key: const Key(
                  'edit-store-tags',
                ),
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: '검색 키워드',
                  hintText: '커피, 디저트처럼 쉼표로 구분',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: PopqSpacing.sm,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key(
            'submit-store-edit',
          ),
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _selectTime({
    required bool isOpenTime,
  }) async {
    final currentValue =
    isOpenTime ? _openTime : _closeTime;

    final selected = await showTimePicker(
      context: context,
      initialTime:
      currentValue ?? TimeOfDay.now(),
      helpText: isOpenTime
          ? '영업 시작 시간'
          : '영업 종료 시간',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isOpenTime) {
        _openTime = selected;
      } else {
        _closeTime = selected;
      }
    });
  }

  void _submit() {
    final name =
    _nameController.text.trim();

    final address =
    _addressController.text.trim();

    final detailAddress =
    _detailAddressController.text.trim();

    final phone =
    _phoneController.text.trim();

    final imageUrl =
    _imageUrlController.text.trim();

    final latitudeText =
    _latitudeController.text.trim();

    final longitudeText =
    _longitudeController.text.trim();

    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);

    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);

    if (name.isEmpty) {
      setState(() {
        _error = '사업장 이름을 입력해 주세요.';
      });
      return;
    }

    if (_representativeCategory == null) {
      setState(() {
        _error = '대표 카테고리를 선택해 주세요.';
      });
      return;
    }

    if (address.isEmpty) {
      setState(() {
        _error = '주소를 입력해 주세요.';
      });
      return;
    }

    if (detailAddress.isEmpty) {
      setState(() {
        _error = '상세 주소를 입력해 주세요.';
      });
      return;
    }

    if (phone.isEmpty) {
      setState(() {
        _error = '사업장 연락처를 입력해 주세요.';
      });
      return;
    }

    final phonePattern = RegExp(
      r'^[0-9+\-()\s]+$',
    );

    if (!phonePattern.hasMatch(phone)) {
      setState(() {
        _error = '연락처 형식을 확인해 주세요.';
      });
      return;
    }

    if (imageUrl.isNotEmpty) {
      final uri = Uri.tryParse(imageUrl);

      final validScheme =
          uri?.scheme == 'http' ||
              uri?.scheme == 'https';

      if (uri == null ||
          !validScheme ||
          uri.host.isEmpty) {
        setState(() {
          _error = '대표 이미지 URL 형식을 확인해 주세요.';
        });
        return;
      }
    }

    if (_openTime == null ||
        _closeTime == null) {
      setState(() {
        _error = '영업 시작 시간과 종료 시간을 선택해 주세요.';
      });
      return;
    }

    if (!_takeoutAvailable &&
        !_dineInAvailable) {
      setState(() {
        _error = '포장 또는 매장 식사 중 하나는 가능해야 합니다.';
      });
      return;
    }

    if ((latitudeText.isEmpty) !=
        (longitudeText.isEmpty) ||
        (latitudeText.isNotEmpty &&
            (latitude == null ||
                longitude == null))) {
      setState(() {
        _error = '위도와 경도를 올바르게 함께 입력해 주세요.';
      });
      return;
    }

    if ((latitude != null &&
        (latitude < -90 ||
            latitude > 90)) ||
        (longitude != null &&
            (longitude < -180 ||
                longitude > 180))) {
      setState(() {
        _error = '위도 또는 경도 범위를 확인해 주세요.';
      });
      return;
    }

    final tags = <String>[];

    for (final rawTag
    in _tagsController.text.split(',')) {
      final tag = rawTag
          .trim()
          .replaceFirst(
        RegExp(r'^#+'),
        '',
      )
          .trim();

      if (tag.isEmpty) {
        continue;
      }

      final duplicated = tags.any(
            (current) =>
        current.toLowerCase() ==
            tag.toLowerCase(),
      );

      if (!duplicated) {
        tags.add(tag);
      }
    }

    if (tags.length > 8) {
      setState(() {
        _error = '검색 키워드는 최대 8개까지 입력할 수 있습니다.';
      });
      return;
    }

    if (tags.any(
          (tag) => tag.length > 30,
    )) {
      setState(() {
        _error = '검색 키워드는 각각 30자 이하여야 합니다.';
      });
      return;
    }

    Navigator.pop(
      context,
      _StoreEditValue(
        name: name,
        description: _emptyToNull(
          _descriptionController.text,
        ),
        address: address,
        detailAddress: detailAddress,
        representativeCategory:
        _representativeCategory!,
        imageUrl: imageUrl.isEmpty
            ? null
            : imageUrl,
        phone: phone,
        latitude: latitude,
        longitude: longitude,
        openTime: _toApiTime(
          _openTime!,
        ),
        closeTime: _toApiTime(
          _closeTime!,
        ),
        closedDays: _days.keys
            .where(_closedDays.contains)
            .toList(
          growable: false,
        ),
        takeoutAvailable:
        _takeoutAvailable,
        dineInAvailable:
        _dineInAvailable,
        orderAcceptingEnabled:
        _orderAcceptingEnabled,
        tags: tags,
      ),
    );
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final parts = value.split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  String _formatTime(TimeOfDay time) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(
      time,
      alwaysUse24HourFormat: true,
    );
  }

  String _toApiTime(TimeOfDay time) {
    final hour =
    time.hour.toString().padLeft(2, '0');

    final minute =
    time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty
        ? null
        : trimmed;
  }
}