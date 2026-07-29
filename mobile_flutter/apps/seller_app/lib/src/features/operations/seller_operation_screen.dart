import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../products/seller_product_list_screen.dart';
import '../products/seller_product_repository.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

class SellerOperationScreen extends StatefulWidget {
  const SellerOperationScreen({
    required this.storeRepository,
    required this.productRepository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository storeRepository;
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
            1 => const PopqEmptyView(
              icon: Icons.campaign_outlined,
              title: '등록된 공지사항이 없어요.',
              description: '공지 작성·게시 API를 연결하면 이곳에서 사업장 공지를 관리합니다.',
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
            ],
          ),
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
      final stores = await widget.storeRepository.findAll();
      final store = stores.firstWhere((item) => item.storeId == _storeId);
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
