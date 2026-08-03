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
  State<StoreSelectionScreen> createState() {
    return _StoreSelectionScreenState();
  }
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  late Future<List<SellerStore>> _stores;

  bool _selecting = false;
  bool _creating = false;

  int? _deletingStoreId;
  int? _observedSelectedStoreId;

  bool get _busy {
    return _selecting ||
        _creating ||
        _deletingStoreId != null;
  }

  @override
  void initState() {
    super.initState();

    _observedSelectedStoreId =
        widget.controller.selectedStoreId;

    widget.controller.addListener(
      _handleSelectionChanged,
    );

    _stores = _load();
  }

  @override
  void didUpdateWidget(
      covariant StoreSelectionScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller ==
        widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(
      _handleSelectionChanged,
    );

    _observedSelectedStoreId =
        widget.controller.selectedStoreId;

    widget.controller.addListener(
      _handleSelectionChanged,
    );

    _stores = _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(
      _handleSelectionChanged,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SellerStore>>(
      future: _stores,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const PopqLoadingView(
            message: '내 스토어를 불러오고 있어요.',
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData) {
          return PopqErrorView(
            message: '내 스토어를 불러오지 못했어요.',
            onRetry: _reload,
          );
        }

        final List<SellerStore> stores =
            snapshot.requireData;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: [
              Text(
                '사업장 대시보드',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              const Text(
                '운영 중인 전체 사업장을 확인하고 새 사업장을 등록할 수 있습니다.',
              ),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              FilledButton.icon(
                key: const Key('add-store'),
                onPressed: _busy
                    ? null
                    : _openRegistrationScreen,
                icon: _creating
                    ? const SizedBox.square(
                  dimension: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.add_business_rounded,
                ),
                label: Text(
                  _creating
                      ? '등록 화면 여는 중...'
                      : '새 사업장 등록',
                ),
              ),
              const SizedBox(
                height: PopqSpacing.lg,
              ),
              if (stores.isEmpty)
                const PopqEmptyView(
                  icon:
                  Icons.storefront_outlined,
                  title: '등록된 사업장이 없어요.',
                  description:
                  '새 사업장 등록을 눌러 첫 운영 공간을 만들어 주세요.',
                ),
              for (final SellerStore store
              in stores)
                _buildStoreCard(store),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreCard(
      SellerStore store,
      ) {
    final bool selected =
        widget.controller.selectedStoreId ==
            store.storeId;

    final bool deleting =
        _deletingStoreId == store.storeId;

    final bool canDelete =
        store.myRole == 'OWNER';

    return Card(
      child: ListTile(
        enabled: !_busy,
        leading: CircleAvatar(
          child: Icon(
            store.storeType ==
                'EVENT_COMMERCE'
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
              ),
            if (canDelete) ...[
              const SizedBox(width: 4),
              if (deleting)
                const SizedBox.square(
                  dimension: 24,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  tooltip: '사업장 삭제',
                  onPressed: _busy
                      ? null
                      : () {
                    _confirmDelete(store);
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                ),
            ],
          ],
        ),
        onTap: _busy
            ? null
            : () {
          _select(store);
        },
      ),
    );
  }

  Future<List<SellerStore>> _load() async {
    final List<SellerStore> stores =
    await widget.repository.findAll();

    final int? selectedId =
        widget.controller.selectedStoreId;

    final bool selectedStoreExists =
        selectedId == null ||
            stores.any(
                  (SellerStore store) {
                return store.storeId ==
                    selectedId;
              },
            );

    if (!selectedStoreExists) {
      _observedSelectedStoreId = null;

      await widget.controller.clear();
    }

    return stores;
  }

  void _handleSelectionChanged() {
    final int? selectedStoreId =
        widget.controller.selectedStoreId;

    if (_observedSelectedStoreId ==
        selectedStoreId) {
      return;
    }

    _observedSelectedStoreId =
        selectedStoreId;

    if (!mounted) {
      return;
    }

    setState(() {
      _stores = _load();
    });
  }

  Future<void> _select(
      SellerStore store,
      ) async {
    if (_busy) {
      return;
    }

    setState(() {
      _selecting = true;
    });

    try {
      /*
       * 기존 사업장을 선택할 때는 목록을 다시 조회할
       * 필요가 없으므로 리스너의 중복 갱신을 막습니다.
       */
      _observedSelectedStoreId =
          store.storeId;

      await widget.controller.select(
        store.storeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selecting = false;
      });

      context.go(
        SellerRoutes.operations,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _observedSelectedStoreId =
          widget.controller.selectedStoreId;

      setState(() {
        _selecting = false;
      });

      _showMessage(
        '스토어 선택을 저장하지 못했어요.',
      );
    }
  }

  Future<void>
  _openRegistrationScreen() async {
    if (_busy) {
      return;
    }

    setState(() {
      _creating = true;
    });

    final Future<SellerStore?> routeFuture =
    context.push<SellerStore>(
      SellerRoutes.storeRegistration,
    );

    /*
     * 화면 전환이 시작되면 대시보드 버튼의 로딩은
     * 바로 해제합니다.
     *
     * 등록 요청 중복 방지는 등록 화면의
     * _submitting 상태가 담당합니다.
     */
    if (mounted) {
      setState(() {
        _creating = false;
      });
    }

    final SellerStore? created =
    await routeFuture;

    if (!mounted) {
      return;
    }

    /*
     * 결과 전달 여부와 관계없이 등록 화면에서 돌아오면
     * 서버 목록을 다시 조회합니다.
     */
    setState(() {
      _stores = _load();
    });

    if (created != null) {
      _showMessage(
        '${created.name} 사업장을 등록했습니다.',
      );
    }
  }

  Future<void> _confirmDelete(
      SellerStore store,
      ) async {
    if (_busy ||
        store.myRole != 'OWNER') {
      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('사업장 삭제'),
          content: Text(
            '${store.name} 사업장을 삭제할까요?\n\n'
                '판매자 목록에서는 사라지지만 기존 주문과 결제 기록은 보존됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    await _deleteStore(store);
  }

  Future<void> _deleteStore(
      SellerStore store,
      ) async {
    if (_busy) {
      return;
    }

    setState(() {
      _deletingStoreId = store.storeId;
    });

    try {
      await widget.repository.delete(
        store.storeId,
      );

      final bool deletedSelectedStore =
          widget.controller.selectedStoreId ==
              store.storeId;

      if (deletedSelectedStore) {
        /*
         * clear() 알림으로 동일한 목록 조회가 한 번 더
         * 실행되지 않도록 관찰 값을 먼저 맞춥니다.
         */
        _observedSelectedStoreId = null;

        await widget.controller.clear();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _deletingStoreId = null;
        _stores = _load();
      });

      _showMessage(
        '${store.name} 사업장을 삭제했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deletingStoreId = null;
      });

      _showMessage(
        '사업장을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  Future<void> _refresh() async {
    final Future<List<SellerStore>>
    refreshFuture = _load();

    setState(() {
      _stores = refreshFuture;
    });

    await refreshFuture;
  }

  void _reload() {
    setState(() {
      _stores = _load();
    });
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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
  return type == 'EVENT_COMMERCE'
      ? '행사·팝업'
      : '일반 매장';
}