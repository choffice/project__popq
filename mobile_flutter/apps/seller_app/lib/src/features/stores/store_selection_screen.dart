import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import 'seller_store_repository.dart';
import 'seller_store_selection_controller.dart';

class StoreSelectionScreen extends StatefulWidget {
  const StoreSelectionScreen({
    required this.repository,
    required this.controller,
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStoreSelectionController controller;

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  late Future<List<SellerStore>> _stores;
  var _selecting = false;
  var _creating = false;

  @override
  void initState() {
    super.initState();
    _stores = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SellerStore>>(
      future: _stores,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(message: '내 스토어를 불러오고 있어요.');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(message: '내 스토어를 불러오지 못했어요.', onRetry: _reload);
        }
        final stores = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text('사업장 대시보드', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PopqSpacing.sm),
            const Text('운영 중인 전체 사업장을 확인하고 새 사업장을 등록할 수 있습니다.'),
            const SizedBox(height: PopqSpacing.md),
            FilledButton.icon(
              key: const Key('add-store'),
              onPressed: _creating ? null : _showCreateDialog,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('새 사업장 등록'),
            ),
            const SizedBox(height: PopqSpacing.lg),
            if (stores.isEmpty)
              const PopqEmptyView(
                icon: Icons.storefront_outlined,
                title: '등록된 사업장이 없어요.',
                description: '새 사업장 등록을 눌러 첫 운영 공간을 만들어 주세요.',
              ),
            for (final store in stores)
              Card(
                child: ListTile(
                  enabled: !_selecting,
                  leading: CircleAvatar(
                    child: Icon(
                      store.storeType == 'EVENT_COMMERCE'
                          ? Icons.celebration_rounded
                          : Icons.storefront_rounded,
                    ),
                  ),
                  title: Text(store.name),
                  subtitle: Text(
                    '${_typeLabel(store.storeType)} · ${_roleLabel(store.myRole)} · '
                    '${_statusLabel(store.businessStatus)}',
                  ),
                  trailing: widget.controller.selectedStoreId == store.storeId
                      ? const Icon(Icons.check_circle_rounded)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => _select(store),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<List<SellerStore>> _load() async {
    final stores = await widget.repository.findAll();
    final selectedId = widget.controller.selectedStoreId;
    if (selectedId != null &&
        !stores.any((store) => store.storeId == selectedId)) {
      await widget.controller.clear();
    }
    return stores;
  }

  Future<void> _select(SellerStore store) async {
    setState(() => _selecting = true);
    try {
      await widget.controller.select(store.storeId);
      if (mounted) context.go(SellerRoutes.operations);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스토어 선택을 저장하지 못했어요.')));
    }
  }

  void _reload() {
    setState(() => _stores = _load());
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    var storeType = 'LOCAL_STORE';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('새 사업장 등록'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: storeType,
                  decoration: const InputDecoration(labelText: '사업장 유형'),
                  items: const [
                    DropdownMenuItem(
                      value: 'LOCAL_STORE',
                      child: Text('일반 매장'),
                    ),
                    DropdownMenuItem(
                      value: 'EVENT_COMMERCE',
                      child: Text('행사·팝업 판매점'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => storeType = value);
                    }
                  },
                ),
                TextField(
                  key: const Key('store-name'),
                  controller: nameController,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: '사업장 이름'),
                ),
                TextField(
                  controller: addressController,
                  maxLength: 255,
                  decoration: const InputDecoration(labelText: '주소'),
                ),
                TextField(
                  controller: descriptionController,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const Key('submit-store'),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    setState(() => _creating = true);
    try {
      final created = await widget.repository.create(
        storeType: storeType,
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        address: addressController.text.trim(),
      );
      await widget.controller.select(created.storeId);
      if (!mounted) return;
      setState(() {
        _creating = false;
        _stores = _load();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 사업장을 등록했습니다.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사업장을 등록하지 못했습니다.')));
    }
  }
}

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => '소유자',
    'MANAGER' => '매니저',
    'STAFF' => '스태프',
    _ => role,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'CLOSED' => '영업 종료',
    'PRE_OPEN' => '영업 준비',
    _ => status,
  };
}

String _typeLabel(String type) {
  return type == 'EVENT_COMMERCE' ? '행사·팝업' : '일반 매장';
}
