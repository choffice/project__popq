import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../auth/seller_identity_repository.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

class SellerMyScreen extends StatefulWidget {
  const SellerMyScreen({
    required this.storeRepository,
    required this.selectionController,
    required this.identityRepository,
    required this.onSignOut,
    required this.onWithdraw,
    required this.onConnectCustomerAccess,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;
  final SellerIdentityRepository identityRepository;
  final Future<void> Function() onSignOut;
  final Future<void> Function(String? confirmationPhrase) onWithdraw;
  final Future<void> Function() onConnectCustomerAccess;

  @override
  State<SellerMyScreen> createState() => _SellerMyScreenState();
}

class _SellerMyScreenState extends State<SellerMyScreen> {
  SellerStore? _store;
  Object? _error;

  int? _lastSelectedStoreId;
  var _loading = true;
  var _signingOut = false;
  var _withdrawing = false;

  @override
  void initState() {
    super.initState();

    _lastSelectedStoreId = widget.selectionController.selectedStoreId;

    widget.selectionController.addListener(_handleStoreSelectionChanged);

    _loadStore();
  }

  @override
  void didUpdateWidget(covariant SellerMyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectionController == widget.selectionController) {
      return;
    }

    oldWidget.selectionController.removeListener(_handleStoreSelectionChanged);

    widget.selectionController.addListener(_handleStoreSelectionChanged);

    _lastSelectedStoreId = widget.selectionController.selectedStoreId;

    _loadStore();
  }

  @override
  void dispose() {
    widget.selectionController.removeListener(_handleStoreSelectionChanged);

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
              child: PopqLoadingView(message: '판매자 정보를 불러오고 있어요.'),
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
            Text('사업장 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: PopqSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('선택 사업장 관리'),
                    subtitle: const Text('사업장 정보와 운영 설정을 확인합니다.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    enabled: _store != null,
                    onTap: _store == null
                        ? null
                        : () {
                            context.go(SellerRoutes.operations);
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('휴업·폐업 사업장'),
                    subtitle: const Text('휴업 사업장을 재개하거나 폐업 이력을 확인합니다.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showInactiveStores,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: const Text('사업장 전환'),
                    subtitle: const Text('다른 사업장을 선택하거나 새로 등록합니다.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      context.go(SellerRoutes.dashboard);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: const Text('팝큐 고객으로도 이용하기'),
                    subtitle: const Text('이 계정으로 고객 앱 서비스도 이용할 수 있게 연결합니다.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _connectCustomerAccess,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PopqSpacing.xl),
            Text('계정 및 앱', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: PopqSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('내 프로필'),
                    subtitle: const Text('닉네임, 이메일과 프로필 사진을 확인합니다.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      context.push(SellerRoutes.myProfile);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('설정'),
                    subtitle: const Text('테마와 앱 사용 환경을 관리합니다.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      context.push(SellerRoutes.settings);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('고객센터'),
                    subtitle: const Text('자주 묻는 질문과 1:1 문의를 할 수 있어요'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      context.push(SellerRoutes.support);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('앱 정보'),
                    subtitle: const Text('POPQ 판매자 앱 · 개발 버전'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(_signingOut ? '로그아웃 중...' : '로그아웃'),
                    subtitle: const Text('현재 판매자 계정에서 로그아웃합니다.'),
                    trailing: _signingOut
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    enabled: !_signingOut,
                    onTap: _signingOut ? null : _confirmSignOut,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      _withdrawing ? '탈퇴 처리 중...' : '회원 탈퇴',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: const Text('판매자 계정을 탈퇴합니다.'),
                    trailing: _withdrawing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    enabled: !_withdrawing,
                    onTap: _withdrawing ? null : _withdraw,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PopqSpacing.xl),
            _SellerCenterCard(
              onTap: () {
                context.go(SellerRoutes.customers);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _handleStoreSelectionChanged() {
    final selectedStoreId = widget.selectionController.selectedStoreId;

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

    final selectedStoreId = widget.selectionController.selectedStoreId;

    if (selectedStoreId == null) {
      setState(() {
        _store = null;
        _loading = false;
      });

      return;
    }

    try {
      final store = await widget.storeRepository.findOne(selectedStoreId);

      if (!mounted ||
          widget.selectionController.selectedStoreId != selectedStoreId) {
        return;
      }

      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          widget.selectionController.selectedStoreId != selectedStoreId) {
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
          content: const Text('현재 판매자 계정에서 로그아웃할까요?'),
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
        context.go(SellerRoutes.signIn);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _signingOut = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('로그아웃하지 못했어요.')));
    }
  }

  Future<void> _showInactiveStores() async {
    final List<SellerStore> stores;
    try {
      stores = await widget.storeRepository.findInactive();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('휴업·폐업 사업장을 불러오지 못했습니다.')),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(PopqSpacing.lg),
                child: Text(
                  '휴업·폐업 사업장',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: stores.isEmpty
                    ? const PopqEmptyView(
                        icon: Icons.store_outlined,
                        title: '휴업·폐업 사업장이 없어요.',
                        description: '현재 운영 중인 사업장은 사업장 전환에서 확인할 수 있어요.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(PopqSpacing.md),
                        itemCount: stores.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          final suspended = store.status == 'SUSPENDED';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  store.imageUrl?.isNotEmpty == true
                                  ? NetworkImage(store.imageUrl!)
                                  : null,
                              child: store.imageUrl?.isNotEmpty == true
                                  ? null
                                  : Icon(
                                      suspended
                                          ? Icons.pause_circle_outline_rounded
                                          : Icons.block_outlined,
                                    ),
                            ),
                            title: Text(store.name),
                            subtitle: Text(
                              '${suspended ? '휴업 중' : '폐업'}'
                              '${store.address?.isNotEmpty == true ? ' · ${store.address}' : ''}',
                            ),
                            trailing: suspended && store.myRole == 'OWNER'
                                ? FilledButton.tonal(
                                    onPressed: () =>
                                        _reopenStore(sheetContext, store),
                                    child: const Text('재개'),
                                  )
                                : const Text('조회만 가능'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reopenStore(
    BuildContext sheetContext,
    SellerStore store,
  ) async {
    final SellerStore reopened;
    try {
      reopened = await widget.storeRepository.reopen(store.storeId);
      await widget.selectionController.select(reopened.storeId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('사업장을 재개하지 못했습니다.')));
      return;
    }
    if (!mounted || !sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사업장을 재개했습니다'),
        content: const Text(
          '영업 시작 전 아래 항목을 확인해 주세요.\n\n'
          '□ 영업시간\n'
          '□ 메뉴와 가격\n'
          '□ 품절 상태\n'
          '□ 주문 접수 설정\n'
          '□ 대표 이미지와 주소',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectCustomerAccess() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팝큐 고객으로도 이용하기'),
        content: const Text(
          '이 계정으로 고객 앱 서비스도 이용할 수 있게 연결할까요?\n'
          '연결 후에는 같은 이메일과 비밀번호로 고객 앱에 로그인할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('연결하기'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.onConnectCustomerAccess();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('팝큐 고객 연결이 완료됐어요. 같은 계정으로 고객 앱에 로그인해 보세요.'),
        ),
      );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(SnackBar(content: Text('팝큐 고객 연결에 실패했어요. ($error)')));
    }
  }

  Future<void> _withdraw() async {
    final SellerIdentity identity;
    try {
      identity = await widget.identityRepository.getCurrent();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('계정 정보를 불러오지 못했어요.')));
      return;
    }

    if (!mounted) return;

    final expectedPhrase = '${identity.name} / 탈퇴하겠습니다';
    final result = await showDialog<_SellerWithdrawDialogResult>(
      context: context,
      builder: (context) =>
          _SellerWithdrawDialog(expectedPhrase: expectedPhrase),
    );

    if (result == null || !mounted) return;

    setState(() {
      _withdrawing = true;
    });

    try {
      await widget.onWithdraw(result.immediate ? expectedPhrase : null);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            result.immediate
                ? '탈퇴가 완료됐어요.'
                : '탈퇴가 접수됐어요. 7일 안에 다시 로그인하면 탈퇴가 취소돼요.',
          ),
        ),
      );
      context.go(SellerRoutes.signIn);
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _withdrawing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _withdrawing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(SnackBar(content: Text('회원 탈퇴에 실패했어요. ($error)')));
    }
  }
}

class _SellerWithdrawDialogResult {
  const _SellerWithdrawDialogResult({required this.immediate});

  final bool immediate;
}

class _SellerWithdrawDialog extends StatefulWidget {
  const _SellerWithdrawDialog({required this.expectedPhrase});

  final String expectedPhrase;

  @override
  State<_SellerWithdrawDialog> createState() => _SellerWithdrawDialogState();
}

class _SellerWithdrawDialogState extends State<_SellerWithdrawDialog> {
  final _controller = TextEditingController();
  bool _matchesPhrase = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('회원 탈퇴'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '탈퇴를 누르면 바로 사라지지 않고, 7일의 유예기간 뒤에 확정돼요.\n'
            '그 안에 다시 로그인하면 탈퇴가 자동으로 취소돼요.',
          ),
          const SizedBox(height: PopqSpacing.md),
          Text(
            '유예기간 없이 지금 바로 탈퇴하려면 아래에\n'
            '"${widget.expectedPhrase}"\n'
            '를 정확히 입력하세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PopqSpacing.sm),
          TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: widget.expectedPhrase),
            onChanged: (value) {
              setState(() {
                _matchesPhrase =
                    _stripSpaces(value) == _stripSpaces(widget.expectedPhrase);
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const _SellerWithdrawDialogResult(immediate: false)),
          child: const Text('7일 후 탈퇴'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _matchesPhrase
              ? () => Navigator.of(
                  context,
                ).pop(const _SellerWithdrawDialogResult(immediate: true))
              : null,
          child: const Text('지금 바로 탈퇴'),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.store});

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
                ? const Icon(Icons.storefront_rounded, size: 34)
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
                    color: colorScheme.onInverseSurface.withValues(alpha: 0.72),
                  ),
                ),
                if (store?.representativeCategory?.isNotEmpty == true) ...[
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

String _stripSpaces(String value) => value.replaceAll(RegExp(r'\s+'), '');

class _SellerCenterCard extends StatelessWidget {
  const _SellerCenterCard({required this.onTap});

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
                child: const Icon(Icons.support_agent_rounded),
              ),
              const SizedBox(width: PopqSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POPQ 고객 문의',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: PopqSpacing.xs),
                    Text('고객 문의와 읽지 않은 메시지를 확인하세요.'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
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
    'PRE_OPEN' => '준비중',
    _ => status,
  };
}
