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
          return const PopqLoadingView(
            message: '내 스토어를 불러오고 있어요.',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '내 스토어를 불러오지 못했어요.',
            onRetry: _reload,
          );
        }

        final stores = snapshot.requireData;

        return ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '사업장 대시보드',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PopqSpacing.sm),
            const Text(
              '운영 중인 전체 사업장을 확인하고 새 사업장을 등록할 수 있습니다.',
            ),
            const SizedBox(height: PopqSpacing.md),

            FilledButton.icon(
              key: const Key('add-store'),
              onPressed: _creating ? null : _openRegistrationScreen,
              icon: _creating
                  ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.add_business_rounded),
              label: Text(
                _creating ? '등록 화면 여는 중...' : '새 사업장 등록',
              ),
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
                  enabled: !_selecting && !_creating,
                  leading: CircleAvatar(
                    child: Icon(
                      store.storeType == 'EVENT_COMMERCE'
                          ? Icons.celebration_rounded
                          : Icons.storefront_rounded,
                    ),
                  ),
                  title: Text(store.name),
                  subtitle: Text(
                    '${_typeLabel(store.storeType)} · '
                        '${_roleLabel(store.myRole)} · '
                        '${_statusLabel(store.businessStatus)}',
                  ),
                  trailing:
                  widget.controller.selectedStoreId == store.storeId
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
    if (_selecting || _creating) {
      return;
    }

    setState(() => _selecting = true);

    try {
      await widget.controller.select(store.storeId);

      if (!mounted) {
        return;
      }

      context.go(SellerRoutes.operations);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _selecting = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('스토어 선택을 저장하지 못했어요.'),
          ),
        );
    }
  }

  Future<void> _openRegistrationScreen() async {
    if (_creating) {
      return;
    }

    setState(() => _creating = true);

    final created = await context.push<SellerStore>(
      SellerRoutes.storeRegistration,
    );

    if (!mounted) {
      return;
    }

    if (created == null) {
      setState(() => _creating = false);
      return;
    }

    setState(() {
      _creating = false;
      _stores = _load();
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${created.name} 사업장을 등록했습니다.'),
        ),
      );
  }

  void _reload() {
    setState(() {
      _stores = _load();
    });
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