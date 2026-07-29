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
        if (stores.isEmpty) {
          return const PopqEmptyView(
            icon: Icons.storefront_outlined,
            title: '소속 스토어가 없어요.',
            description: '판매자 웹 또는 관리자에게 스토어 등록과 멤버 초대를 요청해 주세요.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '운영할 스토어를 선택하세요.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PopqSpacing.sm),
            const Text('활성 멤버십이 있는 스토어만 표시됩니다.'),
            const SizedBox(height: PopqSpacing.lg),
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
                    '${_roleLabel(store.myRole)} · ${_statusLabel(store.businessStatus)}',
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
      if (mounted) context.go(SellerRoutes.home);
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
