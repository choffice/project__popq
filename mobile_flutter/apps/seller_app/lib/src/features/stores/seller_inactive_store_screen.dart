import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'seller_store_repository.dart';
import 'seller_store_selection_controller.dart';

class SellerInactiveStoreScreen extends StatefulWidget {
  const SellerInactiveStoreScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerInactiveStoreScreen> createState() =>
      _SellerInactiveStoreScreenState();
}

class _SellerInactiveStoreScreenState
    extends State<SellerInactiveStoreScreen> {
  List<SellerStore> _stores = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stores = await widget.repository.findInactive();

      if (!mounted) return;

      setState(() {
        _stores = stores;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴업·폐업 사업장'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(
        message: '휴업·폐업 사업장을 불러오고 있어요.',
      );
    }

    if (_error != null) {
      return PopqErrorView(
        message: '휴업·폐업 사업장을 불러오지 못했습니다.',
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });

          _load();
        },
      );
    }

    if (_stores.isEmpty) {
      return const PopqEmptyView(
        icon: Icons.store_outlined,
        title: '휴업·폐업 사업장이 없어요.',
        description: '현재 운영 중인 사업장은 사업장 전환에서 확인할 수 있어요.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      itemCount: _stores.length,
      separatorBuilder: (_, _) =>
      const SizedBox(height: PopqSpacing.sm),
      itemBuilder: (context, index) {
        final store = _stores[index];
        final suspended = store.status == 'SUSPENDED';

        return Card(
          child: ListTile(
            leading: Icon(
              suspended
                  ? Icons.pause_circle_outline_rounded
                  : Icons.block_outlined,
            ),
            title: Text(store.name),
            subtitle: Text(
              suspended ? '휴업 중' : '폐업',
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
            ),
          ),
        );
      },
    );
  }
}