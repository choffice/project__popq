import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../announcements/seller_announcement_repository.dart';
import '../announcements/seller_announcement_screen.dart';
import '../products/seller_product_list_screen.dart';
import '../products/seller_product_repository.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

class SellerOperationScreen extends StatefulWidget {
  const SellerOperationScreen({
    required this.storeRepository,
    required this.announcementRepository,
    required this.productRepository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerAnnouncementRepository announcementRepository;
  final SellerProductRepository productRepository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerOperationScreen> createState() => _SellerOperationScreenState();
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
      return const PopqLoadingView(message: '선택한 사업장 운영정보를 불러오고 있어요.');
    }
    if (_error != null || _store == null) {
      return PopqErrorView(message: '사업장 운영정보를 불러오지 못했습니다.', onRetry: _load);
    }
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(PopqSpacing.sm),
            children: [
              _sectionChip(0, '운영정보', Icons.storefront_outlined),
              _sectionChip(1, '공지사항', Icons.campaign_outlined),
              _sectionChip(2, '메뉴 관리', Icons.restaurant_menu_outlined),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            0 => _operationInfo(),
            1 => SellerAnnouncementScreen(
              storeId: _storeId,
              canManage:
                  _store!.myRole == 'OWNER' || _store!.myRole == 'MANAGER',
              repository: widget.announcementRepository,
            ),
            _ => SellerProductListScreen(
              repository: widget.productRepository,
              selectionController: widget.selectionController,
            ),
          },
        ),
      ],
    );
  }

  Widget _sectionChip(int index, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: PopqSpacing.xs),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: _section == index,
        onSelected: (_) => setState(() => _section = index),
      ),
    );
  }

  Widget _operationInfo() {
    final store = _store!;
    final canManage = store.myRole == 'OWNER' || store.myRole == 'MANAGER';
    return ListView(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          decoration: BoxDecoration(
            color: PopqPalette.ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '현재 선택된 사업장',
                style: TextStyle(color: PopqPalette.lime),
              ),
              const SizedBox(height: PopqSpacing.xs),
              Text(
                store.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: PopqSpacing.sm),
              Text(
                '${_typeLabel(store.storeType)} · ${_roleLabel(store.myRole)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: PopqSpacing.lg),
        Text('영업 상태 관리', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PopqSpacing.sm),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'PRE_OPEN', label: Text('영업 준비')),
            ButtonSegment(value: 'OPEN', label: Text('영업 중')),
            ButtonSegment(value: 'CLOSED', label: Text('영업 종료')),
          ],
          selected: {store.businessStatus},
          onSelectionChanged: !canManage || _changingStatus
              ? null
              : (selection) => _changeStatus(selection.single),
        ),
        if (!canManage)
          const Padding(
            padding: EdgeInsets.only(top: PopqSpacing.sm),
            child: Text('OWNER 또는 MANAGER만 영업 상태를 변경할 수 있습니다.'),
          ),
        if (_changingStatus) const LinearProgressIndicator(),
        const SizedBox(height: PopqSpacing.lg),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('내 권한'),
                trailing: Text(_roleLabel(store.myRole)),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('사업장 상태'),
                trailing: Text(store.status == 'ACTIVE' ? '활성' : store.status),
              ),
              if (store.description?.isNotEmpty == true)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('설명'),
                  subtitle: Text(store.description!),
                ),
              if (store.address?.isNotEmpty == true)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('주소'),
                  subtitle: Text(store.address!),
                ),
              if (store.latitude != null && store.longitude != null)
                ListTile(
                  leading: const Icon(Icons.my_location_outlined),
                  title: const Text('좌표'),
                  subtitle: Text('${store.latitude}, ${store.longitude}'),
                ),
              if (store.tags.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('태그'),
                  subtitle: Text(store.tags.join(', ')),
                ),
            ],
          ),
        ),
        const SizedBox(height: PopqSpacing.md),
        FilledButton.icon(
          key: const Key('edit-store'),
          onPressed: canManage ? _editStore : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('사업장 정보 수정'),
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await widget.storeRepository.findOne(_storeId);
      if (!mounted) return;
      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(String status) async {
    if (status == _store?.businessStatus) return;
    setState(() => _changingStatus = true);
    try {
      final updated = await widget.storeRepository.changeBusinessStatus(
        _storeId,
        status,
      );
      if (!mounted) return;
      setState(() {
        _store = updated;
        _changingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _changingStatus = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('영업 상태를 변경하지 못했습니다.')));
    }
  }

  Future<void> _editStore() async {
    final current = _store;
    if (current == null) return;
    final value = await showDialog<_StoreEditValue>(
      context: context,
      builder: (context) => _StoreEditDialog(store: current),
    );
    if (value == null || !mounted) return;
    try {
      final updated = await widget.storeRepository.update(
        _storeId,
        name: value.name,
        description: value.description,
        address: value.address,
        latitude: value.latitude,
        longitude: value.longitude,
        tags: value.tags,
      );
      if (!mounted) return;
      setState(() => _store = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사업장 정보를 수정했습니다.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사업장 정보를 수정하지 못했습니다.')));
    }
  }
}

String _typeLabel(String type) =>
    type == 'EVENT_COMMERCE' ? '행사·팝업 판매점' : '일반 매장';

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => '소유자',
    'MANAGER' => '매니저',
    'STAFF' => '스태프',
    _ => role,
  };
}

class _StoreEditValue {
  const _StoreEditValue({
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.tags,
  });

  final String name;
  final String? description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> tags;
}

class _StoreEditDialog extends StatefulWidget {
  const _StoreEditDialog({required this.store});

  final SellerStore store;

  @override
  State<_StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<_StoreEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _tagsController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _nameController = TextEditingController(text: store.name);
    _descriptionController = TextEditingController(text: store.description);
    _addressController = TextEditingController(text: store.address);
    _latitudeController = TextEditingController(
      text: store.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: store.longitude?.toString() ?? '',
    );
    _tagsController = TextEditingController(text: store.tags.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사업장 정보 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('edit-store-name'),
              controller: _nameController,
              maxLength: 150,
              decoration: const InputDecoration(labelText: '사업장 이름'),
            ),
            TextField(
              controller: _descriptionController,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: '설명'),
            ),
            TextField(
              key: const Key('edit-store-address'),
              controller: _addressController,
              maxLength: 255,
              decoration: const InputDecoration(labelText: '주소'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: '위도'),
                  ),
                ),
                const SizedBox(width: PopqSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: '경도'),
                  ),
                ),
              ],
            ),
            TextField(
              key: const Key('edit-store-tags'),
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '검색 태그',
                hintText: '커피, 디저트처럼 쉼표로 구분',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: PopqSpacing.sm),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('submit-store-edit'),
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if (name.isEmpty) {
      setState(() => _error = '사업장 이름을 입력해 주세요.');
      return;
    }
    if ((latitudeText.isEmpty) != (longitudeText.isEmpty) ||
        (latitudeText.isNotEmpty && (latitude == null || longitude == null))) {
      setState(() => _error = '위도와 경도를 올바르게 함께 입력해 주세요.');
      return;
    }
    if ((latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      setState(() => _error = '위도 또는 경도 범위를 확인해 주세요.');
      return;
    }
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(10)
        .toList();
    if (tags.any((tag) => tag.length > 30)) {
      setState(() => _error = '태그는 각각 30자 이하여야 합니다.');
      return;
    }
    Navigator.pop(
      context,
      _StoreEditValue(
        name: name,
        description: _emptyToNull(_descriptionController.text),
        address: _emptyToNull(_addressController.text),
        latitude: latitude,
        longitude: longitude,
        tags: tags,
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
