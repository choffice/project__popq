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
  State<StoreSelectionScreen> createState() =>
      _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  late Future<List<SellerStore>> _stores;
  final TextEditingController _searchController = TextEditingController();

  bool _selecting = false;
  bool _creating = false;
  int? _observedSelectedStoreId;
  String _searchQuery = '';
  Map<int, SellerDashboardSummary> _summariesByStoreId = const {};

  bool get _busy => _selecting || _creating;

  @override
  void initState() {
    super.initState();
    _observedSelectedStoreId = widget.controller.selectedStoreId;
    widget.controller.addListener(_handleSelectionChanged);
    _stores = _load();
  }

  @override
  void didUpdateWidget(covariant StoreSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleSelectionChanged);
    _observedSelectedStoreId = widget.controller.selectedStoreId;
    widget.controller.addListener(_handleSelectionChanged);
    _stores = _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSelectionChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SellerStore>>(
      future: _stores,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<SellerStore>> snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(
            message: '사업장을 불러오고 있어요.',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '사업장을 불러오지 못했어요.',
            onRetry: _reload,
          );
        }

        final List<SellerStore> stores = snapshot.requireData;
        final List<SellerStore> visibleStores = _search(stores);
        _showDashboardNoticeAfterFrame();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: <Widget>[
              Text(
                '사업장 대시보드',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: PopqSpacing.sm),
              const Text(
                '운영 중인 사업장을 확인하고 관리할 사업장을 선택하세요.',
              ),
              const SizedBox(height: PopqSpacing.md),
              FilledButton.icon(
                key: const Key('add-store'),
                onPressed: _busy ? null : _openRegistrationScreen,
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business_rounded),
                label: Text(
                  _creating ? '등록 화면 여는 중...' : '새 사업장 등록',
                ),
              ),
              const SizedBox(height: PopqSpacing.lg),
              TextField(
                controller: _searchController,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: '사업장 검색',
                  hintText: '사업장명, 주소, 상세주소, 대표 카테고리',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색어 지우기',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (String value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: PopqSpacing.lg),
              if (stores.isEmpty)
                const PopqEmptyView(
                  icon: Icons.storefront_outlined,
                  title: '등록된 사업장이 없어요.',
                  description: '새 사업장 등록을 눌러 첫 운영 공간을 만들어 주세요.',
                )
              else if (visibleStores.isEmpty)
                const PopqEmptyView(
                  icon: Icons.search_off_rounded,
                  title: '조건에 맞는 사업장이 없습니다.',
                  description: '검색어를 지우고 다시 확인해 주세요.',
                )
              else
                for (final SellerStore store in visibleStores)
                  _buildStoreCard(store),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreCard(SellerStore store) {
    final bool selected =
        widget.controller.selectedStoreId == store.storeId;

    final summary = _summariesByStoreId[store.storeId];
    return Card(
      child: ListTile(
        enabled: !_busy,
        leading: CircleAvatar(
          child: Icon(
            store.storeType == 'EVENT_COMMERCE'
                ? Icons.celebration_rounded
                : Icons.storefront_rounded,
          ),
        ),
        title: Text(store.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_typeLabel(store.storeType)} · '
              '${_roleLabel(store.myRole)} · '
              '${_statusLabel(store.businessStatus)}'
              '${selected ? ' · 현재 선택' : ''}',
            ),
            if (summary != null) ...[
              const SizedBox(height: PopqSpacing.sm),
              Wrap(
                spacing: PopqSpacing.xs,
                runSpacing: PopqSpacing.xs,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 16),
                    label: Text('접수대기 ${summary.waitingOrderCount}'),
                    onPressed: _busy ? null : () => _openOrders(store),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.soup_kitchen_outlined, size: 16),
                    label: Text('진행중 ${summary.activeOrderCount}'),
                    onPressed: _busy ? null : () => _openOrders(store),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: Text('픽업대기 ${summary.readyOrderCount}'),
                    onPressed: _busy ? null : () => _openOrders(store),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.reviews_outlined, size: 16),
                    label: Text('미답변 ${summary.unansweredReviewCount}'),
                    onPressed: _busy ? null : () => _openReviews(store),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.chevron_right_rounded,
        ),
        onTap: _busy
            ? null
            : () {
                _select(store);
              },
      ),
    );
  }

  List<SellerStore> _search(List<SellerStore> stores) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return stores;
    }

    return stores.where((SellerStore store) {
      return <String?>[
        store.name,
        store.address,
        store.detailAddress,
        store.representativeCategory,
      ].any(
        (String? value) => value?.toLowerCase().contains(query) ?? false,
      );
    }).toList(growable: false);
  }

  Future<List<SellerStore>> _load() async {
    final results = await Future.wait([
      widget.repository.findAll(),
      widget.repository.findDashboardSummaries(),
    ]);
    final stores = results[0] as List<SellerStore>;
    final summaries = results[1] as List<SellerDashboardSummary>;
    _summariesByStoreId = {
      for (final summary in summaries) summary.storeId: summary,
    };
    final int? selectedId = widget.controller.selectedStoreId;
    final bool selectedStoreExists = selectedId == null ||
        stores.any((SellerStore store) => store.storeId == selectedId);

    if (!selectedStoreExists) {
      _observedSelectedStoreId = null;
      await widget.controller.clear();
    }

    return stores;
  }

  void _handleSelectionChanged() {
    final int? selectedStoreId = widget.controller.selectedStoreId;
    if (_observedSelectedStoreId == selectedStoreId) {
      return;
    }

    _observedSelectedStoreId = selectedStoreId;
    if (!mounted) {
      return;
    }

    setState(() {
      _stores = _load();
    });
  }

  void _showDashboardNoticeAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final String? notice = widget.controller.takeDashboardNotice();
      if (notice != null) {
        _showMessage(notice);
      }
    });
  }

  Future<void> _select(SellerStore store) async {
    if (_busy) {
      return;
    }

    setState(() {
      _selecting = true;
    });

    try {
      _observedSelectedStoreId = store.storeId;
      await widget.controller.select(store.storeId);

      if (!mounted) {
        return;
      }

      setState(() {
        _selecting = false;
      });
      context.go(SellerRoutes.operations);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _observedSelectedStoreId = widget.controller.selectedStoreId;
      setState(() {
        _selecting = false;
      });
      _showMessage('사업장 선택을 저장하지 못했어요.');
    }
  }

  Future<void> _openOrders(SellerStore store) async {
    await widget.controller.select(store.storeId);
    if (mounted) context.go(SellerRoutes.orders);
  }

  Future<void> _openReviews(SellerStore store) async {
    await widget.controller.select(store.storeId);
    if (mounted) context.go('${SellerRoutes.operations}?section=reviews');
  }

  Future<void> _openRegistrationScreen() async {
    if (_busy) {
      return;
    }

    setState(() {
      _creating = true;
    });

    final Future<SellerStore?> routeFuture =
        context.push<SellerStore>(SellerRoutes.storeRegistration);

    if (mounted) {
      setState(() {
        _creating = false;
      });
    }

    final SellerStore? created = await routeFuture;
    if (!mounted) {
      return;
    }

    setState(() {
      _stores = _load();
    });

    if (created != null) {
      _showMessage('${created.name} 사업장을 등록했습니다.');
    }
  }

  Future<void> _refresh() async {
    final Future<List<SellerStore>> refreshFuture = _load();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    'CLOSED' => '운영 종료',
    'PRE_OPEN' => '영업 준비',
    _ => status,
  };
}

String _typeLabel(String type) {
  return type == 'EVENT_COMMERCE' ? '행사·이벤트' : '로컬마켓';
}
