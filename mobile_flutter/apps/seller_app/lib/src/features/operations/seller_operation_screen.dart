import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../auth/seller_identity_repository.dart';
import '../announcements/seller_announcement_repository.dart';
import '../announcements/seller_announcement_screen.dart';
import '../home/seller_analytics_repository.dart';
import '../products/seller_product_list_screen.dart';
import '../products/seller_product_repository.dart';
import '../orders/seller_order_repository.dart';
import '../sales/seller_sales_screen.dart';
import '../reviews/seller_review_repository.dart';
import '../reviews/seller_review_section.dart';
import '../stores/seller_business_schedule.dart';
import '../stores/seller_store_edit_screen.dart';
import '../stores/seller_store_location_picker_screen.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';
import '../stores/seller_tag_editor.dart';

class SellerOperationScreen extends StatefulWidget {
  const SellerOperationScreen({
    required this.storeRepository,
    required this.announcementRepository,
    required this.productRepository,
    required this.analyticsRepository,
    required this.reviewRepository,
    required this.orderRepository,
    required this.selectionController,
    this.identityRepository,
    this.initialSection = 0,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerAnnouncementRepository announcementRepository;
  final SellerProductRepository productRepository;
  final SellerAnalyticsRepository analyticsRepository;
  final SellerReviewRepository reviewRepository;
  final SellerOrderRepository orderRepository;
  final SellerStoreSelectionController selectionController;
  final SellerIdentityRepository? identityRepository;
  final int initialSection;

  @override
  State<SellerOperationScreen> createState() =>
      _SellerOperationScreenState();
}

class _SellerOperationScreenState extends State<SellerOperationScreen> {
  static const Object _unchanged = Object();
  static const List<String> _categories = <String>[
    '移댄럹',
    '?붿???,
    '踰좎씠而ㅻ━',
    '?쒖떇',
    '以묒떇',
    '?쇱떇',
    '?묒떇',
    '遺꾩떇',
    '移섑궓',
    '?쇱옄',
    '?⑥뒪?명뫖??,
    '二쇱젏',
    '?몃뱶?몃윮',
    '?앹뾽쨌?됱궗',
    '?뚮━留덉폆쨌?됱궗',
    '湲고?',
  ];
  var _section = 0;
  final ImagePicker _imagePicker = ImagePicker();

  SellerStore? _store;
  Object? _error;

  var _loading = true;
  var _changingStatus = false;
  var _savingQuickEdit = false;
  var _pickingHeaderImage = false;
  var _endingOperation = false;
  var _requestSerial = 0;

  int get _storeId => widget.selectionController.selectedStoreId!;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 4).toInt();
    widget.selectionController.addListener(_handleSelectionChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant SellerOperationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionController != widget.selectionController) {
      oldWidget.selectionController.removeListener(_handleSelectionChanged);
      widget.selectionController.addListener(_handleSelectionChanged);
      _load();
    }
  }

  @override
  void dispose() {
    widget.selectionController.removeListener(_handleSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(
        message: '?좏깮???ъ뾽???댁쁺?뺣낫瑜?遺덈윭?ㅺ퀬 ?덉뼱??',
      );
    }

    if (_error != null || _store == null) {
      return PopqErrorView(
        message: '?ъ뾽???댁쁺?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??',
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
                '?댁쁺?뺣낫',
                Icons.storefront_outlined,
              ),
              _sectionChip(
                1,
                '怨듭??ы빆',
                Icons.campaign_outlined,
              ),
              _sectionChip(
                2,
                '硫붾돱 愿由?,
                Icons.restaurant_menu_outlined,
              ),
              _sectionChip(
                3,
                '留ㅼ텧',
                Icons.query_stats_outlined,
              ),
              _sectionChip(
                4,
                '由щ럭',
                Icons.reviews_outlined,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            0 => _operationInfo(),
            1 => SellerAnnouncementScreen(
              key: ValueKey<int>(_storeId),
              storeId: _storeId,
              canManage: _store!.canManage,
              repository: widget.announcementRepository,
            ),
            2 => SellerProductListScreen(
              repository: widget.productRepository,
              selectionController: widget.selectionController,
            ),
            3 => SellerSalesScreen(
              storeRepository: widget.storeRepository,
              analyticsRepository: widget.analyticsRepository,
              selectionController: widget.selectionController,
            ),
            _ => SellerReviewSection(
              storeId: _storeId,
              canReply: _store!.canManage,
              repository: widget.reviewRepository,
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

        // ?좏깮?덉쓣 ???꾩씠肄??먮━???섑??섎뒗 泥댄겕 ?쒖떆 ?쒓굅
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
    final bool canChangeType = store.isOwner;
    final bool operationEnded =
        store.businessStatus == 'CLOSED' || store.status != 'ACTIVE';

    return ListView(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      children: [
        _storeTitleCard(store, canManage: canManage),
        const SizedBox(height: PopqSpacing.sm),
        _businessScheduleCard(store, canManage: canManage),
        const SizedBox(height: PopqSpacing.lg),

        Text(
          '?곸뾽 ?곹깭 愿由?,
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
                    operationEnded ? '?댁쁺 醫낅즺' : '?곸뾽 以鍮?,
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
                  operationEnded
                      ? '醫낅즺??
                      : store.businessStatus == 'OPEN'
                          ? '?곸뾽 以?
                          : '以鍮?以?,
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
              'OWNER ?먮뒗 MANAGER留??곸뾽 ?곹깭瑜?蹂寃쏀븷 ???덉뒿?덈떎.',
            ),
          ),

        const SizedBox(height: PopqSpacing.lg),

        Text(
          '?ъ뾽??湲곕낯 ?뺣낫',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        Card(
          child: Column(
            children: [
              _editableTile(
                icon: Icons.storefront_outlined,
                title: '?ъ뾽?λ챸',
                value: store.name,
                canEdit: canManage,
                onTap: _editName,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.business_outlined,
                title: '?ъ뾽???좏삎',
                value: _typeLabel(store.storeType),
                canEdit: canManage && canChangeType,
                onTap: _editStoreType,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                ),
                title: const Text('??沅뚰븳'),
                trailing: Text(
                  _roleLabel(store.myRole),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                ),
                title: const Text('?ъ뾽???곹깭'),
                trailing: Text(
                  store.status == 'ACTIVE'
                      ? '?쒖꽦'
                      : store.status,
                ),
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.category_outlined,
                title: '???移댄뀒怨좊━',
                value: _displayValue(store.representativeCategory),
                canEdit: canManage,
                onTap: _editRepresentativeCategory,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.description_outlined,
                title: '?ㅻ챸',
                value: _displayValue(store.description),
                canEdit: canManage,
                onTap: _editDescription,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.location_on_outlined,
                title: '二쇱냼',
                value: _fullAddress(store).isEmpty
                    ? '?깅줉?섏? ?딆쓬'
                    : _fullAddress(store),
                canEdit: canManage,
                onTap: _editAddress,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.phone_outlined,
                title: '?곕씫泥?,
                value: _displayValue(store.phone),
                canEdit: canManage,
                onTap: _editPhone,
              ),
              const Divider(height: 1),
              _editableTile(
                icon: Icons.sell_outlined,
                title: '寃???ㅼ썙??,
                value: store.tags.isEmpty
                    ? '?깅줉?섏? ?딆쓬'
                    : store.tags.map((String tag) => '#$tag').join(', '),
                canEdit: canManage,
                onTap: _editTags,
              ),
            ],
          ),
        ),

        const SizedBox(height: PopqSpacing.lg),

        Text(
          '二쇰Ц ?댁쁺 ?ㅼ젙',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: PopqSpacing.sm),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.shopping_bag_outlined),
                title: const Text('?ъ옣'),
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
                title: const Text('留ㅼ옣 ?앹궗'),
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
                title: const Text('二쇰Ц ?묒닔'),
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
            '?꾩껜 ?뺣낫 ?섏젙',
          ),
        ),
        if (store.isOwner) ...<Widget>[
          const SizedBox(height: PopqSpacing.lg),
          const Divider(),
          TextButton.icon(
            key: const Key('suspend-store-operation'),
            onPressed: _endingOperation ? null : _confirmSuspendOperation,
            icon: const Icon(Icons.pause_circle_outline_rounded),
            label: const Text('?ъ뾽???댁뾽'),
          ),
          TextButton.icon(
            key: const Key('end-store-operation'),
            onPressed: _endingOperation ? null : _confirmEndOperation,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.block_outlined),
            label: const Text('?ъ뾽???먯뾽'),
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
                    tooltip: '??쒖궗吏?蹂寃?,
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
                      tooltip: '??쒖궗吏??쒓굅',
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
                    '?꾩옱 ?좏깮???ъ뾽??,
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
                    ].join(' 쨌 '),
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

  Widget _businessScheduleCard(
    SellerStore store, {
    required bool canManage,
  }) {
    final schedule = store.schedule ?? SellerBusinessSchedule.legacy(
      openTime: store.openTime,
      closeTime: store.closeTime,
      closedDays: store.closedDays,
    );
    final lines = sellerScheduleSummary(schedule);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.schedule_outlined),
                const SizedBox(width: PopqSpacing.sm),
                Expanded(
                  child: Text(
                    '?곸뾽?쒓컙',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: canManage && !_savingQuickEdit
                      ? _editBusinessSchedule
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('?섏젙'),
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.xs),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: PopqSpacing.xs),
                child: Text(line),
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
    return store.canManage;
  }

  String _displayValue(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? '?깅줉?섏? ?딆쓬' : text;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(
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
    Object? schedule = _unchanged,
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
        schedule: identical(schedule, _unchanged)
            ? null
            : schedule as SellerBusinessSchedule?,
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
      _showMessage('?ъ뾽???뺣낫瑜???ν븯吏 紐삵뻽?듬땲?? ?좎떆 ???ㅼ떆 ?쒕룄??二쇱꽭??');
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
              title: const Text('移대찓?쇰줈 珥ъ쁺'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('媛ㅻ윭由ъ뿉???좏깮'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('痍⑥냼'),
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
        successMessage: '??쒖궗吏꾩쓣 蹂寃쏀뻽?듬땲??',
      );
    } on PopqFailure catch (failure) {
      _showMessage(failure.message);
    } catch (_) {
      _showMessage('??쒖궗吏꾩쓣 蹂寃쏀븯吏 紐삵뻽?듬땲?? 湲곗〈 ?ъ쭊???좎??⑸땲??');
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
        title: const Text('??쒖궗吏꾩쓣 ?쒓굅?좉퉴??'),
        content: const Text(
          '??쒖궗吏??곌껐留??쒓굅?섎ŉ ?쒕쾭???낅줈?쒕맂 ?ㅼ젣 ?뚯씪? ??젣?섏? ?딆뒿?덈떎.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('?ъ쭊 ?쒓굅'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _saveQuickEdit(
      imageUrl: '',
      successMessage: '??쒖궗吏꾩쓣 ?쒓굅?덉뒿?덈떎.',
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
              setDialogState(() => errorText = '?꾩닔 ?낅젰 ??ぉ?낅땲??');
              return;
            }
            if (value.length > maxLength) {
              setDialogState(() => errorText = '理쒕? $maxLength?먭퉴吏 ?낅젰?????덉뒿?덈떎.');
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
                child: const Text('痍⑥냼'),
              ),
              FilledButton(onPressed: submit, child: const Text('???)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName() async {
    final String? value = await _requestTextEdit(
      title: '?ъ뾽?λ챸 ?섏젙',
      initialValue: _store!.name,
      maxLength: 150,
      requiredValue: true,
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(name: value, successMessage: '?ъ뾽?λ챸???섏젙?덉뒿?덈떎.');
  }

  Future<void> _editDescription() async {
    final String? value = await _requestTextEdit(
      title: '?ㅻ챸 ?섏젙',
      initialValue: _store!.description ?? '',
      maxLength: 1000,
      requiredValue: false,
      maxLines: 5,
      hintText: '鍮꾩썙 ?먮㈃ ?ㅻ챸???쒓굅?⑸땲??',
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(description: value, successMessage: '?ㅻ챸???섏젙?덉뒿?덈떎.');
  }

  Future<void> _editPhone() async {
    final String? value = await _requestTextEdit(
      title: '?곕씫泥??섏젙',
      initialValue: _store!.phone ?? '',
      maxLength: 30,
      requiredValue: true,
      keyboardType: TextInputType.phone,
    );
    if (value == null || !mounted) {
      return;
    }
    await _saveQuickEdit(phone: value, successMessage: '?곕씫泥섎? ?섏젙?덉뒿?덈떎.');
  }

  Future<void> _editTags() async {
    final List<String>? tags = await showSellerTagsEditorDialog(
      context,
      initialTags: _store!.tags,
      maxCount: 10,
    );
    if (tags == null || !mounted) {
      return;
    }
    await _saveQuickEdit(
      tags: tags,
      successMessage: '寃???ㅼ썙?쒕? ?섏젙?덉뒿?덈떎.',
    );
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
          title: const Text('???移댄뀒怨좊━ ?섏젙'),
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
              child: const Text('痍⑥냼'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('???),
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
      successMessage: '???移댄뀒怨좊━瑜??섏젙?덉뒿?덈떎.',
    );
  }

  Future<void> _editStoreType() async {
    final SellerStore store = _store!;
    String selected = store.storeType;
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('?ъ뾽???좏삎 ?섏젙'),
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
                  title: Text('?쇰컲 留ㅼ옣'),
                ),
                RadioListTile<String>(
                  value: 'EVENT_COMMERCE',
                  title: Text('?됱궗쨌?앹뾽 ?먮ℓ??),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('痍⑥냼'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('?ㅼ쓬'),
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
        title: const Text('?ъ뾽???좏삎??蹂寃쏀븷源뚯슂?'),
        content: const Text('?ъ뾽???좏삎留?蹂寃쎈릺硫??ㅻⅨ ?ъ뾽???뺣낫??洹몃?濡??좎??⑸땲??'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('?좏삎 蹂寃?),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _saveQuickEdit(storeType: value, successMessage: '?ъ뾽???좏삎???섏젙?덉뒿?덈떎.');
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
              setSheetState(() => errorText = '寃?됲븷 二쇱냼瑜??낅젰??二쇱꽭??');
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
                setSheetState(() => errorText = '二쇱냼 寃??寃곌낵媛 ?놁뒿?덈떎.');
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
                setSheetState(() => errorText = '二쇱냼瑜?寃?됲븯吏 紐삵뻽?듬땲??');
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => searching = false);
              }
            }
          }

          Future<void> searchPlace() async {
            final String? query = await _requestTextEdit(
              title: '移댁뭅???낆껜 寃??,
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
                setSheetState(() => errorText = '移댁뭅???낆껜 寃??寃곌낵媛 ?놁뒿?덈떎.');
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
                setSheetState(() => errorText = '移댁뭅???낆껜瑜?寃?됲븯吏 紐삵뻽?듬땲??');
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
                      ? '?ъ뾽???꾩튂'
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
                setSheetState(() => errorText = '?좏깮???꾩튂??二쇱냼瑜??뺤씤?섏? 紐삵뻽?듬땲??');
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
              setSheetState(() => errorText = '二쇱냼瑜??낅젰??二쇱꽭??');
              return;
            }
            if (!locationConfirmed || latitude == null || longitude == null) {
              setSheetState(
                () => errorText = '二쇱냼 寃???먮뒗 吏???좏깮?쇰줈 ?꾩튂瑜??뺤씤??二쇱꽭??',
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
                    Text('二쇱냼 ?섏젙', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: PopqSpacing.md),
                    TextField(
                      controller: addressController,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: '二쇱냼'),
                      onChanged: (String value) {
                        final bool changed = _normalizeText(value) !=
                            _normalizeText(store.address ?? '');
                        if (changed && locationConfirmed) {
                          setSheetState(() {
                            locationConfirmed = false;
                            latitude = null;
                            longitude = null;
                            errorText = '二쇱냼媛 蹂寃쎈릺?덉뒿?덈떎. ?꾩튂瑜??ㅼ떆 ?뺤씤??二쇱꽭??';
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: detailController,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: '?곸꽭二쇱냼'),
                    ),
                    Wrap(
                      spacing: PopqSpacing.sm,
                      runSpacing: PopqSpacing.sm,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: searching ? null : searchAddress,
                          icon: const Icon(Icons.manage_search_outlined),
                          label: const Text('二쇱냼 寃??),
                        ),
                        OutlinedButton.icon(
                          onPressed: searching ? null : searchPlace,
                          icon: const Icon(Icons.store_mall_directory_outlined),
                          label: const Text('移댁뭅???낆껜 寃??),
                        ),
                        OutlinedButton.icon(
                          onPressed: searching ? null : selectOnMap,
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('吏?꾩뿉???좏깮'),
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
                                ? '?ъ뾽???꾩튂媛 ?뺤씤?섏뿀?듬땲??'
                                : '二쇱냼? ?쇱튂?섎뒗 ?꾩튂瑜??뺤씤??二쇱꽭??',
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
                          child: const Text('痍⑥냼'),
                        ),
                        const SizedBox(width: PopqSpacing.sm),
                        FilledButton(
                          onPressed: searching ? null : submit,
                          child: const Text('???),
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
      successMessage: '二쇱냼? ?꾩튂瑜??섏젙?덉뒿?덈떎.',
    );
  }

  Future<SellerAddressSearchResult?> _selectAddressResult(
    List<SellerAddressSearchResult> results,
  ) {
    return showDialog<SellerAddressSearchResult>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('二쇱냼 ?좏깮'),
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
        title: const Text('?낆껜 ?좏깮'),
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

  Future<void> _editBusinessSchedule() async {
    final store = _store!;
    var edited = store.schedule ?? SellerBusinessSchedule.legacy(
      openTime: store.openTime,
      closeTime: store.closeTime,
      closedDays: store.closedDays,
    );
    final result = await showModalBottomSheet<SellerBusinessSchedule>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.9,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PopqSpacing.lg,
                    PopqSpacing.lg,
                    PopqSpacing.sm,
                    PopqSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '?곸뾽?쒓컙 ?ㅼ젙',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PopqSpacing.lg,
                    ),
                    child: SellerBusinessScheduleEditor(
                      initialSchedule: edited,
                      onChanged: (value) =>
                          setSheetState(() => edited = value),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(PopqSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final error = edited.validationMessage;
                        if (error != null) {
                          ScaffoldMessenger.of(sheetContext)
                            ..hideCurrentTopSnackBar()
                            ..showTopSnackBar(SnackBar(content: Text(error)));
                          return;
                        }
                        Navigator.pop(sheetContext, edited);
                      },
                      child: const Text('???),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _saveQuickEdit(
      openTime: result.legacyOpenTimeForApi,
      closeTime: result.legacyCloseTimeForApi,
      closedDays: result.legacyClosedDays,
      schedule: result,
      successMessage: '?곸뾽?쒓컙???섏젙?덉뒿?덈떎.',
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
      _showMessage('?ъ옣 ?먮뒗 留ㅼ옣 ?앹궗 以??섎굹??媛?ν빐???⑸땲??');
      return;
    }
    await _saveQuickEdit(
      takeoutAvailable: nextTakeout,
      dineInAvailable: nextDineIn,
      orderAcceptingEnabled: identical(orderAcceptingEnabled, _unchanged)
          ? store.orderAcceptingEnabled
          : orderAcceptingEnabled,
      successMessage: '二쇰Ц ?댁쁺 ?ㅼ젙???섏젙?덉뒿?덈떎.',
    );
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  Future<void> _load() async {
    final requestedStoreId = widget.selectionController.selectedStoreId;
    if (requestedStoreId == null) return;
    final requestSerial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = await widget.storeRepository.findOne(
        requestedStoreId,
      );

      if (!mounted || requestSerial != _requestSerial ||
          widget.selectionController.selectedStoreId != requestedStoreId ||
          store.storeId != requestedStoreId) {
        return;
      }

      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial ||
          widget.selectionController.selectedStoreId != requestedStoreId) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _handleSelectionChanged() {
    if (mounted) _load();
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
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '?곸뾽 ?곹깭瑜?蹂寃쏀븯吏 紐삵뻽?듬땲??',
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
            identityRepository: widget.identityRepository,
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
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(
        const SnackBar(
          content: Text(
            '?ъ뾽???뺣낫瑜??섏젙?덉뒿?덈떎.',
          ),
        ),
      );
  }

  Future<void> _confirmEndOperation() async {
    final SellerStore? store = _store;
    if (store == null || !store.isOwner || _endingOperation) {
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
              title: const Text('?ъ뾽?μ쓣 ?먯뾽?좉퉴??'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${store.name}???먯뾽?섎㈃ ?쒖꽦 ?ъ뾽??紐⑸줉?먯꽌 ?щ씪吏怨?'
                    '二쇰Ц ?묒닔媛 以묒??⑸땲??\n\n'
                    '湲곗〈 二쇰Ц怨?寃곗젣 湲곕줉? 蹂댁〈?⑸땲??\n'
                    '?먯뾽 ?꾩뿉??吏곸젒 ?ш컻?????놁뒿?덈떎.',
                  ),
                  const SizedBox(height: PopqSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('???댁슜???뺤씤?덉뒿?덈떎.'),
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
                  child: const Text('痍⑥냼'),
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
                                    '?ъ뾽?μ쓣 ?먯뾽?섏? 紐삵뻽?듬땲?? ?좎떆 ???ㅼ떆 ?쒕룄??二쇱꽭??';
                              });
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('?먯뾽 ?뺤젙'),
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
      dashboardNotice: '?ъ뾽?μ쓣 ?먯뾽?덉뒿?덈떎.',
    );

    if (mounted) {
      context.go(SellerRoutes.dashboard);
    }
  }

  Future<void> _confirmSuspendOperation() async {
    final store = _store;
    if (store == null || !store.isOwner || _endingOperation) return;
    final _SuspensionSummary summary;
    try {
      summary = await _loadSuspensionSummary(store.storeId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('?댁뾽 ???댁쁺 ?붿빟??遺덈윭?ㅼ? 紐삵뻽?듬땲??')),
      );
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?ъ뾽?μ쓣 ?댁뾽?좉퉴??'),
        content: Text(
          '?댁뾽?섎㈃ 怨좉컼?먭쾶 ?몄텧?섏? ?딄퀬 二쇰Ц ?묒닔媛 以묒??⑸땲?? '
          '?ъ뾽???뺣낫? 二쇰Ц쨌硫붾돱쨌由щ럭??洹몃?濡?蹂댁〈?⑸땲??\n\n'
          '留덉?留?二쇰Ц?? ${summary.lastOrderDate}\n'
          '理쒓렐 30??二쇰Ц: ${summary.orderCount}嫄?n'
          '理쒓렐 30??留ㅼ텧: ${summary.sales}??n'
          '誘몃떟蹂 由щ럭: ${summary.unansweredReviewCount}嫄?n'
          '鍮꾪솢?굿룻뭹??硫붾돱: ${summary.unavailableProductCount}媛?,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('?댁뾽?섍린'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _endingOperation = true);
    try {
      await widget.storeRepository.suspend(store.storeId);
      await widget.selectionController.clear(
        dashboardNotice: '?ъ뾽?μ쓣 ?댁뾽?덉뒿?덈떎.',
      );
      if (mounted) context.go(SellerRoutes.dashboard);
    } catch (_) {
      if (!mounted) return;
      setState(() => _endingOperation = false);
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('?ъ뾽?μ쓣 ?댁뾽?섏? 紐삵뻽?듬땲??')),
      );
    }
  }

  Future<_SuspensionSummary> _loadSuspensionSummary(int storeId) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final results = await Future.wait([
      widget.orderRepository.findAll(storeId),
      widget.analyticsRepository.findSales(storeId, from: from, to: now),
      widget.reviewRepository.findAll(storeId, unanswered: true),
      widget.productRepository.findAll(storeId),
    ]);
    final orders = results[0] as List<SellerOrder>;
    final sales = results[1] as SellerSalesSummary;
    final reviews = results[2] as List<SellerReview>;
    final products = results[3] as List<SellerProduct>;
    final dates = orders.map((order) => order.createdAt).whereType<DateTime>().toList()
      ..sort();
    return _SuspensionSummary(
      lastOrderDate: dates.isEmpty
          ? '二쇰Ц ?놁쓬'
          : '${dates.last.toLocal().year}.${dates.last.toLocal().month}.${dates.last.toLocal().day}',
      orderCount: orders.where((order) {
        final createdAt = order.createdAt;
        return createdAt != null && !createdAt.isBefore(from);
      }).length,
      sales: sales.netSales,
      unansweredReviewCount: reviews.length,
      unavailableProductCount: products
          .where((product) => product.status != 'ACTIVE' || product.soldOut)
          .length,
    );
  }
}

class _SuspensionSummary {
  const _SuspensionSummary({
    required this.lastOrderDate,
    required this.orderCount,
    required this.sales,
    required this.unansweredReviewCount,
    required this.unavailableProductCount,
  });

  final String lastOrderDate;
  final int orderCount;
  final int sales;
  final int unansweredReviewCount;
  final int unavailableProductCount;
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
      ? '?됱궗쨌?앹뾽 ?먮ℓ??
      : '?쇰컲 留ㅼ옣';
}

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => '?뚯쑀??,
    'MANAGER' => '留ㅻ땲?',
    'STAFF' => '?ㅽ깭??,
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

