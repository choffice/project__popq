import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

class SellerMyScreen extends StatefulWidget {
  const SellerMyScreen({
    required this.storeRepository,
    required this.selectionController,
    required this.onSignOut,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;
  final Future<void> Function() onSignOut;

  @override
  State<SellerMyScreen> createState() => _SellerMyScreenState();
}

class _SellerMyScreenState extends State<SellerMyScreen> {
  SellerStore? _store;
  Object? _error;

  int? _lastSelectedStoreId;
  var _loading = true;
  var _signingOut = false;

  @override
  void initState() {
    super.initState();

    _lastSelectedStoreId =
        widget.selectionController.selectedStoreId;

    widget.selectionController.addListener(
      _handleStoreSelectionChanged,
    );

    _loadStore();
  }

  @override
  void didUpdateWidget(
    covariant SellerMyScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectionController ==
        widget.selectionController) {
      return;
    }

    oldWidget.selectionController.removeListener(
      _handleStoreSelectionChanged,
    );

    widget.selectionController.addListener(
      _handleStoreSelectionChanged,
    );

    _lastSelectedStoreId =
        widget.selectionController.selectedStoreId;

    _loadStore();
  }

  @override
  void dispose() {
    widget.selectionController.removeListener(
      _handleStoreSelectionChanged,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStore,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: PopqLoadingView(
                message: '판매자 정보를 불러오고 있어요.',
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: PopqErrorView(
                message: '판매자 정보를 불러오지 못했습니다.',
                onRetry: _loadStore,
              ),
            )
          else ...[
            _ProfileCard(store: _store),
            const SizedBox(height: PopqSpacing.xl),
            Text(
              '사업장 관리',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PopqSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.storefront_outlined,
                    ),
                    title: const Text('선택 사업장 관리'),
                    subtitle: const Text(
                      '사업장 정보와 운영 설정을 확인합니다.',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    enabled: _store != null,
                    onTap: _store == null
                        ? null
                        : () {
                            context.go(
                              SellerRoutes.operations,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.swap_horiz_rounded,
                    ),
                    title: const Text('사업장 전환'),
                    subtitle: const Text(
                      '다른 사업장을 선택하거나 새로 등록합니다.',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      context.go(
                        SellerRoutes.dashboard,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: PopqSpacing.xl),
            Text(
              '계정 및 앱',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PopqSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                    ),
                    title: const Text('설정'),
                    subtitle: const Text(
                      '테마와 앱 사용 환경을 관리합니다.',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      context.push(
                        SellerRoutes.settings,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline_rounded,
                    ),
                    title: const Text('앱 정보'),
                    subtitle: const Text(
                      'POPQ 판매자 앱 · 개발 버전',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                    ),
                    title: Text(
                      _signingOut ? '로그아웃 중...' : '로그아웃',
                    ),
                    subtitle: const Text(
                      '현재 판매자 계정에서 로그아웃합니다.',
                    ),
                    trailing: _signingOut
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                          ),
                    enabled: !_signingOut,
                    onTap: _signingOut
                        ? null
                        : _confirmSignOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PopqSpacing.xl),
            _SellerCenterCard(
              onTap: () {
                context.go(
                  SellerRoutes.customers,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _handleStoreSelectionChanged() {
    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (_lastSelectedStoreId == selectedStoreId) {
      return;
    }

    _lastSelectedStoreId = selectedStoreId;
    _loadStore();
  }

  Future<void> _loadStore() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (selectedStoreId == null) {
      setState(() {
        _store = null;
        _loading = false;
      });

      return;
    }

    try {
      final store = await widget.storeRepository.findOne(
        selectedStoreId,
      );

      if (!mounted ||
          widget.selectionController.selectedStoreId !=
              selectedStoreId) {
        return;
      }

      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          widget.selectionController.selectedStoreId !=
              selectedStoreId) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text(
            '현재 판매자 계정에서 로그아웃할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    setState(() {
      _signingOut = true;
    });

    try {
      await widget.onSignOut();

      if (mounted) {
        context.go(
          SellerRoutes.signIn,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _signingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그아웃하지 못했어요.'),
        ),
      );
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.store,
  });

  final SellerStore? store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final store = this.store;

    return Container(
      padding: const EdgeInsets.all(PopqSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: store == null
                ? const Icon(
                    Icons.storefront_rounded,
                    size: 34,
                  )
                : Text(
                    _storeInitial(store.name),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: PopqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store?.name ?? '선택된 사업장이 없어요',
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  store == null
                      ? '대시보드에서 사업장을 선택해 주세요.'
                      : '${_roleLabel(store.myRole)} · '
                          '${_businessStatusLabel(store.businessStatus)}',
                  style: TextStyle(
                    color: colorScheme.onInverseSurface.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
                if (store?.representativeCategory?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: PopqSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PopqSpacing.sm,
                      vertical: PopqSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      store!.representativeCategory!,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerCenterCard extends StatelessWidget {
  const _SellerCenterCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: const Icon(
                  Icons.support_agent_rounded,
                ),
              ),
              const SizedBox(width: PopqSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POPQ 고객 문의',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: PopqSpacing.xs),
                    Text(
                      '고객 문의와 읽지 않은 메시지를 확인하세요.',
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _storeInitial(String name) {
  final trimmed = name.trim();

  if (trimmed.isEmpty) {
    return 'P';
  }

  return trimmed.substring(0, 1);
}

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => '사업자',
    'MANAGER' => '매니저',
    'STAFF' => '직원',
    _ => role,
  };
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'PRE_OPEN' => '영업 준비',
    'CLOSED' => '영업 종료',
    _ => status,
  };
}
