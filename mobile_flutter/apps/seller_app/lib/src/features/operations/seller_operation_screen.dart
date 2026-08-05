import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../announcements/seller_announcement_repository.dart';
import '../announcements/seller_announcement_screen.dart';
import '../home/seller_analytics_repository.dart';
import '../products/seller_product_list_screen.dart';
import '../products/seller_product_repository.dart';
import '../sales/seller_sales_screen.dart';
import '../stores/seller_store_edit_screen.dart';
import '../stores/seller_store_location_picker_screen.dart';
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
  static const Object _unchanged = Object();
  static const List<String> _categories = <String>[
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
  static const Map<String, String> _days = <String, String>{
    'MONDAY': '월',
    'TUESDAY': '화',
    'WEDNESDAY': '수',
    'THURSDAY': '목',
    'FRIDAY': '금',
    'SATURDAY': '토',
    'SUNDAY': '일',
  };

  var _section = 0;
  final ImagePicker _imagePicker = ImagePicker();

  SellerStore? _store;
  Object? _error;

  var _loading = true;
  var _changingStatus = false;
  var _savingQuickEdit = false;
  var _pickingHeaderImage = false;
  var _endingOperation = false;

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
    final bool canManage = _canManage(store);
    final bool canChangeType = store.myRole == 'OWNER';
    final bool operationEnded =
        store.businessStatus == 'CLOSED' || store.status != 'ACTIVE';

    return ListView(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      children: [
        _storeTitleCard(store, canManage: canManage),
        const SizedBox(height: PopqSpacing.lg),

        Text(
          '영업 상태 관리',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PopqSpacing.md,
              vertical: PopqSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    operationEnded ? '운영 종료' : '영업 준비',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: store.businessStatus == 'OPEN' && !operationEnded,
                  onChanged: !canManage ||
                          operationEnded ||
                          _changingStatus ||
                          _savingQuickEdit
                      ? null
                      : (bool value) {
                          _changeStatus(value ? 'OPEN' : 'PRE_OPEN');
                        },
                ),
                const SizedBox(width: PopqSpacing.xs),
                Text(
                  operationEnded ? '종료됨' : '영업 중',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
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
              _editableTile(
                icon: Icons.storefront_outlined,
                title: '사업장명',
                value: store.name,
                canEdit: canManage,
                onTap: _editName,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.business_outlined,
                title: '사업장 유형',
                value: _typeLabel(store.storeType),
                canEdit: canManage && canChangeType,
                onTap: _editStoreType,
              ),
              const Divider(height: 1),
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
              const Divider(height: 1),
              _editableTile(
                icon: Icons.category_outlined,
                title: '대표 카테고리',
                value: _displayValue(store.representativeCategory),
                canEdit: canManage,
                onTap: _editRepresentativeCategory,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.description_outlined,
                title: '설명',
                value: _displayValue(store.description),
                canEdit: canManage,
                onTap: _editDescription,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.location_on_outlined,
                title: '주소',
                value: _fullAddress(store).isEmpty
                    ? '등록되지 않음'
                    : _fullAddress(store),
                canEdit: canManage,
                onTap: _editAddress,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.phone_outlined,
                title: '연락처',
                value: _displayValue(store.phone),
                canEdit: canManage,
                onTap: _editPhone,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.sell_outlined,
                title: '검색 키워드',
                value: store.tags.isEmpty
                    ? '등록되지 않음'
                    : store.tags.map((String tag) => '#$tag').join(', '),
                canEdit: canManage,
                onTap: _editTags,
              ),
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
                trailing: canManage
                    ? const Icon(Icons.edit_outlined)
                    : null,
                onTap: canManage && !_savingQuickEdit ? _editOperatingHours : null,
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
                trailing: canManage
                    ? const Icon(Icons.edit_outlined)
                    : null,
                onTap: canManage && !_savingQuickEdit ? _editClosedDays : null,
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
              SwitchListTile(
                secondary: const Icon(Icons.shopping_bag_outlined),
                title: const Text('포장'),
                value: store.takeoutAvailable,
                onChanged: canManage && !_savingQuickEdit
                    ? (bool value) => _changeOrderPolicy(
                          takeoutAvailable: value,
                        )
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.table_restaurant_outlined),
                title: const Text('매장 식사'),
                value: store.dineInAvailable,
                onChanged: canManage && !_savingQuickEdit
                    ? (bool value) => _changeOrderPolicy(
                          dineInAvailable: value,
                        )
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.receipt_long_outlined),
                title: const Text('주문 접수'),
                value: store.orderAcceptingEnabled,
                onChanged: canManage && !_savingQuickEdit
                    ? (bool value) => _changeOrderPolicy(
                          orderAcceptingEnabled: value,
                        )
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: PopqSpacing.md),

        FilledButton.icon(
          key: const Key('edit-store'),
          onPressed: canManage && !_savingQuickEdit && !_endingOperation
              ? _editStore
              : null,
          icon: const Icon(
            Icons.edit_outlined,
          ),
          label: const Text(
            '전체 정보 수정',
          ),
        ),
        if (store.myRole == 'OWNER') ...<Widget>[
          const SizedBox(height: PopqSpacing.lg),
          const Divider(),
          TextButton.icon(
            key: const Key('end-store-operation'),
            onPressed: _endingOperation ? null : _confirmEndOperation,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.block_outlined),
            label: const Text('사업장 운영 종료'),
          ),
        ],
      ],
    );
  }

  Widget _storeTitleCard(
    SellerStore store, {
    required bool canManage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final String imageUrl = store.imageUrl?.trim() ?? '';
    return SizedBox(
      height: 190,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: colorScheme.inverseSurface,
              child: Icon(
                Icons.storefront_rounded,
                size: 72,
                color: colorScheme.primary.withValues(alpha: 0.68),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x33000000),
                    Color(0xE6000000),
                  ],
                ),
              ),
            ),
            Positioned(
              top: PopqSpacing.sm,
              right: PopqSpacing.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _HeaderImageButton(
                    tooltip: '대표사진 변경',
                    icon: Icons.camera_alt_outlined,
                    onPressed: canManage &&
                            !_savingQuickEdit &&
                            !_pickingHeaderImage
                        ? _changeHeaderImage
                        : null,
                  ),
                  if (imageUrl.isNotEmpty) ...<Widget>[
                    const SizedBox(width: PopqSpacing.xs),
                    _HeaderImageButton(
                      tooltip: '대표사진 제거',
                      icon: Icons.delete_outline_rounded,
                      onPressed: canManage && !_savingQuickEdit
                          ? _removeHeaderImage
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: PopqSpacing.lg,
              right: PopqSpacing.lg,
              bottom: PopqSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '현재 선택된 사업장',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.xs),
                  Text(
                    store.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.xs),
                  Text(
                    <String>[
                      _typeLabel(store.storeType),
                      _roleLabel(store.myRole),
                      if (store.representativeCategory?.trim().isNotEmpty == true)
                        store.representativeCategory!.trim(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (_pickingHeaderImage || _savingQuickEdit)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editableTile({
    required IconData icon,
    required String title,
    required String value,
    required bool canEdit,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: canEdit ? const Icon(Icons.edit_outlined) : null,
      onTap: canEdit && !_savingQuickEdit ? onTap : null,
    );
  }

  bool _canManage(SellerStore store) {
    return store.myRole == 'OWNER' || store.myRole == 'MANAGER';
  }

  String _displayValue(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? '등록되지 않음' : text;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<SellerStore?> _saveQuickEdit({
    Object? storeType = _unchanged,
    Object? name = _unchanged,
    Object? description = _unchanged,
    Object? address = _unchanged,
    Object? detailAddress = _unchanged,
    Object? representativeCategory = _unchanged,
    Object? imageUrl = _unchanged,
    Object? phone = _unchanged,
    Object? latitude = _unchanged,
    Object? longitude = _unchanged,
    Object? openTime = _unchanged,
    Object? closeTime = _unchanged,
    Object? closedDays = _unchanged,
    Object? takeoutAvailable = _unchanged,
    Object? dineInAvailable = _unchanged,
    Object? orderAcceptingEnabled = _unchanged,
    Object? tags = _unchanged,
    String? successMessage,
  }) async {
    final SellerStore? current = _store;
    if (current == null || _savingQuickEdit) {
      return null;
    }

    setState(() => _savingQuickEdit = true);
    try {
      final SellerStore updated = await widget.storeRepository.update(
        current.storeId,
        storeType: identical(storeType, _unchanged)
            ? current.storeType
            : storeType as String?,
        name: identical(name, _unchanged) ? current.name : name as String,
        description: identical(description, _unchanged)
            ? current.description
            : description as String?,
        address: identical(address, _unchanged)
            ? current.address
            : address as String?,
        detailAddress: identical(detailAddress, _unchanged)
            ? current.detailAddress
            : detailAddress as String?,
        representativeCategory:
            identical(representativeCategory, _unchanged)
                ? current.representativeCategory
                : representativeCategory as String?,
        imageUrl: identical(imageUrl, _unchanged)
            ? current.imageUrl
            : imageUrl as String?,
        phone: identical(phone, _unchanged)
            ? current.phone
            : phone as String?,
        latitude: identical(latitude, _unchanged)
            ? current.latitude
            : latitude as double?,
        longitude: identical(longitude, _unchanged)
            ? current.longitude
            : longitude as double?,
        openTime: identical(openTime, _unchanged)
            ? current.openTime
            : openTime as String?,
        closeTime: identical(closeTime, _unchanged)
            ? current.closeTime
            : closeTime as String?,
        closedDays: identical(closedDays, _unchanged)
            ? current.closedDays
            : closedDays as List<String>,
        takeoutAvailable: identical(takeoutAvailable, _unchanged)
            ? current.takeoutAvailable
            : takeoutAvailable as bool,
        dineInAvailable: identical(dineInAvailable, _unchanged)
            ? current.dineInAvailable
            : dineInAvailable as bool,
        orderAcceptingEnabled:
            identical(orderAcceptingEnabled, _unchanged)
                ? current.orderAcceptingEnabled
                : orderAcceptingEnabled as bool,
        tags: identical(tags, _unchanged)
            ? current.tags
            : tags as List<String>,
      );
      if (!mounted) {
        return updated;
      }
      setState(() => _store = updated);
      if (successMessage != null) {
        _showMessage(successMessage);
      }
      return updated;
    } on PopqFailure catch (failure) {
      _showMessage(failure.message);
      return null;
    } catch (_) {
      _showMessage('사업장 정보를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      return null;
    } finally {
      if (mounted) {
        setState(() => _savingQuickEdit = false);
      }
    }
  }

  Future<void> _changeHeaderImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('취소'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }

    setState(() => _pickingHeaderImage = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) {
        return;
      }
      final String uploadedUrl = await widget.storeRepository
          .uploadRepresentativeImage(image.path);
      if (!mounted) {
        return;
      }
      await _saveQuickEdit(
        imageUrl: uploadedUrl,
        successMessage: '대표사진을 변경했습니다.',
      );
    } on PopqFailure catch (failure) {
      _showMessage(failure.message);
    } catch (_) {
      _showMessage('대표사진을 변경하지 못했습니다. 기존 사진을 유지합니다.');
    } finally {
      if (mounted) {
        setState(() => _pickingHeaderImage = false);
      }
    }
  }

  Future<void> _removeHeaderImage() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('대표사진을 제거할까요?'),
        content: const Text(
          '대표사진 연결만 제거되며 서버에 업로드된 실제 파일은 삭제되지 않습니다.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('사진 제거'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _saveQuickEdit(
      imageUrl: '',
      successMessage: '대표사진을 제거했습니다.',
    );
  }

  Future<String?> _requestTextEdit({
    required String title,
    required String initialValue,
    required int maxLength,
    required bool requiredValue,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          void submit() {
            final String value = controller.text.trim();
            if (requiredValue && value.isEmpty) {
              setDialogState(() => errorText = '필수 입력 항목입니다.');
              return;
            }
            if (value.length > maxLength) {
              setDialogState(() => errorText = '최대 $maxLength자까지 입력할 수 있습니다.');
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              maxLines: maxLines,
              keyboardType: keyboardType,
              textInputAction:
                  maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hintText,
                errorText: errorText,
              ),
              onSubmitted: maxLines == 1 ? (_) => submit() : null,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
              FilledButton(onPressed: submit, child: const Text('저장')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName() async {
    final String? value = await _requestTextEdit(
      title: '사업장명 수정',
      initialValue: _store!.name,
      maxLength: 150,
      requiredValue: true,
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(name: value, successMessage: '사업장명을 수정했습니다.');
  }

  Future<void> _editDescription() async {
    final String? value = await _requestTextEdit(
      title: '설명 수정',
      initialValue: _store!.description ?? '',
      maxLength: 1000,
      requiredValue: false,
      maxLines: 5,
      hintText: '비워 두면 설명이 제거됩니다.',
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(description: value, successMessage: '설명을 수정했습니다.');
  }

  Future<void> _editPhone() async {
    final String? value = await _requestTextEdit(
      title: '연락처 수정',
      initialValue: _store!.phone ?? '',
      maxLength: 30,
      requiredValue: true,
      keyboardType: TextInputType.phone,
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(phone: value, successMessage: '연락처를 수정했습니다.');
  }

  Future<void> _editTags() async {
    final String? value = await _requestTextEdit(
      title: '검색 키워드 수정',
      initialValue: _store!.tags.join(', '),
      maxLength: 310,
      requiredValue: false,
      maxLines: 3,
      hintText: '쉼표로 구분해 최대 10개까지 입력',
    );
    if (value == null || !mounted) {
      return;
    }
    final List<String> parsed = _parseTags(value);
    if (parsed.length > 10) {
      _showMessage('검색 키워드는 최대 10개까지 입력할 수 있습니다.');
      return;
    }
    if (parsed.any((String tag) => tag.length > 30)) {
      _showMessage('검색 키워드는 각각 30자 이하여야 합니다.');
      return;
    }
    await _saveQuickEdit(tags: parsed, successMessage: '검색 키워드를 수정했습니다.');
  }

  List<String> _parseTags(String value) {
    final List<String> tags = <String>[];
    for (final String raw in value.split(',')) {
      final String tag = raw
          .trim()
          .replaceFirst(RegExp(r'^#+'), '')
          .toLowerCase();
      if (tag.isNotEmpty && !tags.contains(tag)) {
        tags.add(tag);
      }
    }
    return List<String>.unmodifiable(tags);
  }

  Future<void> _editRepresentativeCategory() async {
    final SellerStore store = _store!;
    final List<String> options = <String>[
      ..._categories,
      if (store.representativeCategory?.trim().isNotEmpty == true &&
          !_categories.contains(store.representativeCategory!.trim()))
        store.representativeCategory!.trim(),
    ];
    String selected = store.representativeCategory?.trim().isNotEmpty == true
        ? store.representativeCategory!.trim()
        : options.first;
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('대표 카테고리 수정'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: options
                .map(
                  (String option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? next) {
              if (next != null) {
                setDialogState(() => selected = next);
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(
      representativeCategory: value,
      successMessage: '대표 카테고리를 수정했습니다.',
    );
  }

  Future<void> _editStoreType() async {
    final SellerStore store = _store!;
    String selected = store.storeType;
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('사업장 유형 수정'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (String? next) {
              if (next != null) {
                setDialogState(() => selected = next);
              }
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RadioListTile<String>(
                  value: 'LOCAL_STORE',
                  title: Text('일반 매장'),
                ),
                RadioListTile<String>(
                  value: 'EVENT_COMMERCE',
                  title: Text('행사·팝업 판매점'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
    if (value == null || value == store.storeType || !mounted) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('사업장 유형을 변경할까요?'),
        content: const Text('사업장 유형만 변경되며 다른 사업장 정보는 그대로 유지됩니다.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('유형 변경'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _saveQuickEdit(storeType: value, successMessage: '사업장 유형을 수정했습니다.');
  }

  Future<void> _editAddress() async {
    final SellerStore store = _store!;
    final TextEditingController addressController = TextEditingController(
      text: store.address,
    );
    final TextEditingController detailController = TextEditingController(
      text: store.detailAddress,
    );
    double? latitude = store.latitude;
    double? longitude = store.longitude;
    bool locationConfirmed = latitude != null && longitude != null;
    bool searching = false;
    String? errorText;

    final _OperationAddressEditResult? result =
        await showModalBottomSheet<_OperationAddressEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          Future<void> searchAddress() async {
            final String query = addressController.text.trim();
            if (query.isEmpty) {
              setSheetState(() => errorText = '검색할 주소를 입력해 주세요.');
              return;
            }
            setSheetState(() {
              searching = true;
              errorText = null;
            });
            try {
              final List<SellerAddressSearchResult> results =
                  await widget.storeRepository.searchAddresses(query);
              if (!sheetContext.mounted) {
                return;
              }
              if (results.isEmpty) {
                setSheetState(() => errorText = '주소 검색 결과가 없습니다.');
                return;
              }
              final SellerAddressSearchResult? selected =
                  await _selectAddressResult(results);
              if (selected == null || !sheetContext.mounted) {
                return;
              }
              setSheetState(() {
                addressController.text = selected.addressName;
                latitude = selected.latitude;
                longitude = selected.longitude;
                locationConfirmed = true;
              });
            } on PopqFailure catch (failure) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = failure.message);
              }
            } catch (_) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = '주소를 검색하지 못했습니다.');
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => searching = false);
              }
            }
          }

          Future<void> searchPlace() async {
            final String? query = await _requestTextEdit(
              title: '카카오 업체 검색',
              initialValue: <String>[
                addressController.text.trim(),
                store.name,
              ].where((String value) => value.isNotEmpty).join(' '),
              maxLength: 200,
              requiredValue: true,
            );
            if (query == null || !sheetContext.mounted) {
              return;
            }
            setSheetState(() {
              searching = true;
              errorText = null;
            });
            try {
              final List<SellerKakaoPlaceSearchResult> results =
                  await widget.storeRepository.searchPlaces(query);
              if (!sheetContext.mounted) {
                return;
              }
              if (results.isEmpty) {
                setSheetState(() => errorText = '카카오 업체 검색 결과가 없습니다.');
                return;
              }
              final SellerKakaoPlaceSearchResult? selected =
                  await _selectPlaceResult(results);
              if (selected == null || !sheetContext.mounted) {
                return;
              }
              setSheetState(() {
                addressController.text = selected.displayAddress;
                latitude = selected.latitude;
                longitude = selected.longitude;
                locationConfirmed = true;
              });
            } on PopqFailure catch (failure) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = failure.message);
              }
            } catch (_) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = '카카오 업체를 검색하지 못했습니다.');
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => searching = false);
              }
            }
          }

          Future<void> selectOnMap() async {
            final SellerMapLocationPickResult? picked = await Navigator.of(
              sheetContext,
            ).push<SellerMapLocationPickResult>(
              MaterialPageRoute<SellerMapLocationPickResult>(
                builder: (BuildContext context) =>
                    SellerStoreLocationPickerScreen(
                  initialLatitude: latitude ?? 35.157746,
                  initialLongitude: longitude ?? 129.059319,
                  addressLabel: addressController.text.trim().isEmpty
                      ? '사업장 위치'
                      : addressController.text.trim(),
                ),
              ),
            );
            if (picked == null || !sheetContext.mounted) {
              return;
            }
            setSheetState(() {
              searching = true;
              errorText = null;
            });
            try {
              final SellerReverseGeocodeResult resolved =
                  await widget.storeRepository.reverseGeocode(
                latitude: picked.latitude,
                longitude: picked.longitude,
              );
              if (!sheetContext.mounted) {
                return;
              }
              setSheetState(() {
                addressController.text = resolved.displayAddress;
                latitude = resolved.latitude;
                longitude = resolved.longitude;
                locationConfirmed = true;
              });
            } on PopqFailure catch (failure) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = failure.message);
              }
            } catch (_) {
              if (sheetContext.mounted) {
                setSheetState(() => errorText = '선택한 위치의 주소를 확인하지 못했습니다.');
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => searching = false);
              }
            }
          }

          void submit() {
            final String address = addressController.text.trim();
            if (address.isEmpty) {
              setSheetState(() => errorText = '주소를 입력해 주세요.');
              return;
            }
            if (!locationConfirmed || latitude == null || longitude == null) {
              setSheetState(
                () => errorText = '주소 검색 또는 지도 선택으로 위치를 확인해 주세요.',
              );
              return;
            }
            Navigator.of(sheetContext).pop(
              _OperationAddressEditResult(
                address: address,
                detailAddress: detailController.text.trim(),
                latitude: latitude!,
                longitude: longitude!,
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                PopqSpacing.lg,
                PopqSpacing.lg,
                PopqSpacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + PopqSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('주소 수정', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: PopqSpacing.md),
                    TextField(
                      controller: addressController,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: '주소'),
                      onChanged: (String value) {
                        final bool changed = _normalizeText(value) !=
                            _normalizeText(store.address ?? '');
                        if (changed && locationConfirmed) {
                          setSheetState(() {
                            locationConfirmed = false;
                            latitude = null;
                            longitude = null;
                            errorText = '주소가 변경되었습니다. 위치를 다시 확인해 주세요.';
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: detailController,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: '상세주소'),
                    ),
                    Wrap(
                      spacing: PopqSpacing.sm,
                      runSpacing: PopqSpacing.sm,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: searching ? null : searchAddress,
                          icon: const Icon(Icons.manage_search_outlined),
                          label: const Text('주소 검색'),
                        ),
                        OutlinedButton.icon(
                          onPressed: searching ? null : searchPlace,
                          icon: const Icon(Icons.store_mall_directory_outlined),
                          label: const Text('카카오 업체 검색'),
                        ),
                        OutlinedButton.icon(
                          onPressed: searching ? null : selectOnMap,
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('지도에서 선택'),
                        ),
                      ],
                    ),
                    const SizedBox(height: PopqSpacing.sm),
                    Row(
                      children: <Widget>[
                        Icon(
                          locationConfirmed
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: PopqSpacing.xs),
                        Expanded(
                          child: Text(
                            locationConfirmed
                                ? '사업장 위치가 확인되었습니다.'
                                : '주소와 일치하는 위치를 확인해 주세요.',
                          ),
                        ),
                      ],
                    ),
                    if (errorText != null) ...<Widget>[
                      const SizedBox(height: PopqSpacing.sm),
                      Text(
                        errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (searching) ...<Widget>[
                      const SizedBox(height: PopqSpacing.sm),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: PopqSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: searching
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: PopqSpacing.sm),
                        FilledButton(
                          onPressed: searching ? null : submit,
                          child: const Text('저장'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) {
      return;
    }
    await _saveQuickEdit(
      address: result.address,
      detailAddress: result.detailAddress,
      latitude: result.latitude,
      longitude: result.longitude,
      successMessage: '주소와 위치를 수정했습니다.',
    );
  }

  Future<SellerAddressSearchResult?> _selectAddressResult(
    List<SellerAddressSearchResult> results,
  ) {
    return showDialog<SellerAddressSearchResult>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('주소 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final SellerAddressSearchResult result = results[index];
                return ListTile(
                  title: Text(result.addressName),
                  subtitle: result.roadAddressName == null
                      ? null
                      : Text(result.roadAddressName!),
                  onTap: () => Navigator.of(dialogContext).pop(result),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<SellerKakaoPlaceSearchResult?> _selectPlaceResult(
    List<SellerKakaoPlaceSearchResult> results,
  ) {
    return showDialog<SellerKakaoPlaceSearchResult>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('업체 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final SellerKakaoPlaceSearchResult result = results[index];
                return ListTile(
                  title: Text(result.placeName),
                  subtitle: Text(result.displayAddress),
                  onTap: () => Navigator.of(dialogContext).pop(result),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editOperatingHours() async {
    TimeOfDay? open = _parseTimeOfDay(_store!.openTime);
    TimeOfDay? close = _parseTimeOfDay(_store!.closeTime);
    String? errorText;
    final List<TimeOfDay>? result = await showDialog<List<TimeOfDay>>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('영업시간 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: const Text('시작 시간'),
                trailing: Text(open == null ? '선택' : _formatTimeOfDay(open!)),
                onTap: () async {
                  final TimeOfDay? selected = await showTimePicker(
                    context: dialogContext,
                    initialTime: open ?? TimeOfDay.now(),
                    helpText: '영업 시작 시간',
                  );
                  if (selected != null) {
                    setDialogState(() => open = selected);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('종료 시간'),
                trailing: Text(close == null ? '선택' : _formatTimeOfDay(close!)),
                onTap: () async {
                  final TimeOfDay? selected = await showTimePicker(
                    context: dialogContext,
                    initialTime: close ?? TimeOfDay.now(),
                    helpText: '영업 종료 시간',
                  );
                  if (selected != null) {
                    setDialogState(() => close = selected);
                  }
                },
              ),
              if (errorText != null)
                Text(
                  errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (open == null || close == null) {
                  setDialogState(() => errorText = '시작 시간과 종료 시간을 모두 선택해 주세요.');
                  return;
                }
                Navigator.of(dialogContext).pop(<TimeOfDay>[open!, close!]);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _saveQuickEdit(
      openTime: _toApiTime(result[0]),
      closeTime: _toApiTime(result[1]),
      successMessage: '영업시간을 수정했습니다.',
    );
  }

  Future<void> _editClosedDays() async {
    final Set<String> selected = <String>{..._store!.closedDays};
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('정기 휴무일 수정'),
          content: Wrap(
            spacing: PopqSpacing.sm,
            runSpacing: PopqSpacing.sm,
            children: _days.entries
                .map(
                  (MapEntry<String, String> entry) => FilterChip(
                    label: Text(entry.value),
                    selected: selected.contains(entry.key),
                    onSelected: (bool value) {
                      setDialogState(() {
                        if (value) {
                          selected.add(entry.key);
                        } else {
                          selected.remove(entry.key);
                        }
                      });
                    },
                  ),
                )
                .toList(growable: false),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _days.keys.where(selected.contains).toList(growable: false),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _saveQuickEdit(
      closedDays: result,
      successMessage: '정기 휴무일을 수정했습니다.',
    );
  }

  Future<void> _changeOrderPolicy({
    Object? takeoutAvailable = _unchanged,
    Object? dineInAvailable = _unchanged,
    Object? orderAcceptingEnabled = _unchanged,
  }) async {
    final SellerStore store = _store!;
    final bool nextTakeout = identical(takeoutAvailable, _unchanged)
        ? store.takeoutAvailable
        : takeoutAvailable as bool;
    final bool nextDineIn = identical(dineInAvailable, _unchanged)
        ? store.dineInAvailable
        : dineInAvailable as bool;
    if (!nextTakeout && !nextDineIn) {
      _showMessage('포장 또는 매장 식사 중 하나는 가능해야 합니다.');
      return;
    }
    await _saveQuickEdit(
      takeoutAvailable: nextTakeout,
      dineInAvailable: nextDineIn,
      orderAcceptingEnabled: identical(orderAcceptingEnabled, _unchanged)
          ? store.orderAcceptingEnabled
          : orderAcceptingEnabled,
      successMessage: '주문 운영 설정을 수정했습니다.',
    );
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final List<String> parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      value,
      alwaysUse24HourFormat: true,
    );
  }

  String _toApiTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:00';
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
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

  Future<void> _confirmEndOperation() async {
    final SellerStore? store = _store;
    if (store == null || store.myRole != 'OWNER' || _endingOperation) {
      return;
    }

    final bool? ended = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool confirmed = false;
        bool submitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setDialogState,
          ) {
            return AlertDialog(
              title: const Text('사업장 운영을 종료할까요?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${store.name}의 운영을 종료하면 판매자 사업장 목록에서 사라지고 '
                    '주문 접수가 중지됩니다.\n\n'
                    '기존 주문과 결제 기록은 보존됩니다.\n'
                    '현재 앱에서는 운영 종료 후 직접 복구할 수 없습니다.',
                  ),
                  const SizedBox(height: PopqSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('위 내용을 확인했습니다.'),
                    value: confirmed,
                    onChanged: submitting
                        ? null
                        : (bool? value) {
                            setDialogState(() {
                              confirmed = value ?? false;
                              errorMessage = null;
                            });
                          },
                  ),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('취소'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: !confirmed || submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                            errorMessage = null;
                          });
                          if (mounted) {
                            setState(() {
                              _endingOperation = true;
                            });
                          }

                          try {
                            await widget.storeRepository.delete(store.storeId);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                _endingOperation = false;
                              });
                            }
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                submitting = false;
                                errorMessage =
                                    '사업장 운영을 종료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
                              });
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('운영 종료'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ended != true || !mounted) {
      return;
    }

    await widget.selectionController.clear(
      dashboardNotice: '사업장 운영을 종료했습니다.',
    );

    if (mounted) {
      context.go(SellerRoutes.dashboard);
    }
  }
}

class _HeaderImageButton extends StatelessWidget {
  const _HeaderImageButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      shape: const CircleBorder(),
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _OperationAddressEditResult {
  const _OperationAddressEditResult({
    required this.address,
    required this.detailAddress,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final String detailAddress;
  final double latitude;
  final double longitude;
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
