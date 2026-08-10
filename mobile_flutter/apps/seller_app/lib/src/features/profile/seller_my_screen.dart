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
                message: '?먮ℓ???뺣낫瑜?遺덈윭?ㅺ퀬 ?덉뼱??',
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: PopqErrorView(
                message: '?먮ℓ???뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??',
                onRetry: _loadStore,
              ),
            )
          else ...[
            _ProfileCard(store: _store),
            const SizedBox(height: PopqSpacing.xl),
            Text(
              '?ъ뾽??愿由?,
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
                    title: const Text('?좏깮 ?ъ뾽??愿由?),
                    subtitle: const Text(
                      '?ъ뾽???뺣낫? ?댁쁺 ?ㅼ젙???뺤씤?⑸땲??',
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
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('?댁뾽쨌?먯뾽 ?ъ뾽??),
                    subtitle: const Text('?댁뾽 ?ъ뾽?μ쓣 ?ш컻?섍굅???먯뾽 ?대젰???뺤씤?⑸땲??'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showInactiveStores,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.swap_horiz_rounded,
                    ),
                    title: const Text('?ъ뾽???꾪솚'),
                    subtitle: const Text(
                      '?ㅻⅨ ?ъ뾽?μ쓣 ?좏깮?섍굅???덈줈 ?깅줉?⑸땲??',
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.person_add_alt_1_rounded,
                    ),
                    title: const Text('?앺걧 怨좉컼?쇰줈???댁슜?섍린'),
                    subtitle: const Text(
                      '??怨꾩젙?쇰줈 怨좉컼 ???쒕퉬?ㅻ룄 ?댁슜?????덇쾶 ?곌껐?⑸땲??',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: _connectCustomerAccess,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PopqSpacing.xl),
            Text(
              '怨꾩젙 諛???,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PopqSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline_rounded,
                    ),
                    title: const Text('???꾨줈??),
                    subtitle: const Text(
                      '?대쫫, ?대찓?쇨낵 ?꾨줈???ъ쭊???뺤씤?⑸땲??',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      context.push(
                        SellerRoutes.myProfile,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                    ),
                    title: const Text('?ㅼ젙'),
                    subtitle: const Text(
                      '?뚮쭏? ???ъ슜 ?섍꼍??愿由ы빀?덈떎.',
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
                    title: const Text('???뺣낫'),
                    subtitle: const Text(
                      'POPQ ?먮ℓ????쨌 媛쒕컻 踰꾩쟾',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                    ),
                    title: Text(
                      _signingOut ? '濡쒓렇?꾩썐 以?..' : '濡쒓렇?꾩썐',
                    ),
                    subtitle: const Text(
                      '?꾩옱 ?먮ℓ??怨꾩젙?먯꽌 濡쒓렇?꾩썐?⑸땲??',
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
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      _withdrawing ? '?덊눜 泥섎━ 以?..' : '?뚯썝 ?덊눜',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: const Text(
                      '?먮ℓ??怨꾩젙???덊눜?⑸땲??',
                    ),
                    trailing: _withdrawing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                          ),
                    enabled: !_withdrawing,
                    onTap: _withdrawing ? null : _withdraw,
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
          title: const Text('濡쒓렇?꾩썐'),
          content: const Text(
            '?꾩옱 ?먮ℓ??怨꾩젙?먯꽌 濡쒓렇?꾩썐?좉퉴??',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('痍⑥냼'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('濡쒓렇?꾩썐'),
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

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('濡쒓렇?꾩썐?섏? 紐삵뻽?댁슂.'),
        ),
      );
    }
  }

  Future<void> _showInactiveStores() async {
    final List<SellerStore> stores;
    try {
      stores = await widget.storeRepository.findInactive();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('?댁뾽쨌?먯뾽 ?ъ뾽?μ쓣 遺덈윭?ㅼ? 紐삵뻽?듬땲??')),
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
                  '?댁뾽쨌?먯뾽 ?ъ뾽??,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: stores.isEmpty
                    ? const PopqEmptyView(
                        icon: Icons.store_outlined,
                        title: '?댁뾽쨌?먯뾽 ?ъ뾽?μ씠 ?놁뼱??',
                        description: '?꾩옱 ?댁쁺 以묒씤 ?ъ뾽?μ? ?ъ뾽???꾪솚?먯꽌 ?뺤씤?????덉뼱??',
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
                              backgroundImage: store.imageUrl?.isNotEmpty == true
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
                              '${suspended ? '?댁뾽 以? : '?먯뾽'}'
                              '${store.address?.isNotEmpty == true ? ' 쨌 ${store.address}' : ''}',
                            ),
                            trailing: suspended && store.myRole == 'OWNER'
                                ? FilledButton.tonal(
                                    onPressed: () => _reopenStore(
                                      sheetContext,
                                      store,
                                    ),
                                    child: const Text('?ш컻'),
                                  )
                                : const Text('議고쉶留?媛??),
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
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('?ъ뾽?μ쓣 ?ш컻?섏? 紐삵뻽?듬땲??')),
      );
      return;
    }
    if (!mounted || !sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?ъ뾽?μ쓣 ?ш컻?덉뒿?덈떎'),
        content: const Text(
          '?곸뾽 ?쒖옉 ???꾨옒 ??ぉ???뺤씤??二쇱꽭??\n\n'
          '???곸뾽?쒓컙\n'
          '??硫붾돱? 媛寃?n'
          '???덉젅 ?곹깭\n'
          '??二쇰Ц ?묒닔 ?ㅼ젙\n'
          '??????대?吏? 二쇱냼',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('?뺤씤'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectCustomerAccess() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?앺걧 怨좉컼?쇰줈???댁슜?섍린'),
        content: const Text(
          '??怨꾩젙?쇰줈 怨좉컼 ???쒕퉬?ㅻ룄 ?댁슜?????덇쾶 ?곌껐?좉퉴??\n'
          '?곌껐 ?꾩뿉??媛숈? ?대찓?쇨낵 鍮꾨?踰덊샇濡?怨좉컼 ?깆뿉 濡쒓렇?명븷 ???덉뼱??',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('?곌껐?섍린'),
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
          content: Text(
            '?앺걧 怨좉컼 ?곌껐???꾨즺?먯뼱?? 媛숈? 怨꾩젙?쇰줈 怨좉컼 ?깆뿉 濡쒓렇?명빐 蹂댁꽭??',
          ),
        ),
      );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text('?앺걧 怨좉컼 ?곌껐???ㅽ뙣?덉뼱?? ($error)'),
        ),
      );
    }
  }

  Future<void> _withdraw() async {
    final SellerIdentity identity;
    try {
      identity = await widget.identityRepository.getCurrent();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('怨꾩젙 ?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?댁슂.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final expectedPhrase = '${identity.name} / ?덊눜?섍쿋?듬땲??;
    final result = await showDialog<_SellerWithdrawDialogResult>(
      context: context,
      builder: (context) => _SellerWithdrawDialog(
        expectedPhrase: expectedPhrase,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _withdrawing = true;
    });

    try {
      await widget.onWithdraw(
        result.immediate ? expectedPhrase : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            result.immediate
                ? '?덊눜媛 ?꾨즺?먯뼱??'
                : '?덊눜媛 ?묒닔?먯뼱?? 7???덉뿉 ?ㅼ떆 濡쒓렇?명븯硫??덊눜媛 痍⑥냼?쇱슂.',
          ),
        ),
      );
      context.go(SellerRoutes.signIn);
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _withdrawing = false;
      });
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _withdrawing = false;
      });
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text('?뚯썝 ?덊눜???ㅽ뙣?덉뼱?? ($error)'),
        ),
      );
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
      title: const Text('?뚯썝 ?덊눜'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '?덊눜瑜??꾨Ⅴ硫?諛붾줈 ?щ씪吏吏 ?딄퀬, 7?쇱쓽 ?좎삁湲곌컙 ?ㅼ뿉 ?뺤젙?쇱슂.\n'
            '洹??덉뿉 ?ㅼ떆 濡쒓렇?명븯硫??덊눜媛 ?먮룞?쇰줈 痍⑥냼?쇱슂.',
          ),
          const SizedBox(height: PopqSpacing.md),
          Text(
            '?좎삁湲곌컙 ?놁씠 吏湲?諛붾줈 ?덊눜?섎젮硫??꾨옒??n'
            '"${widget.expectedPhrase}"\n'
            '瑜??뺥솗???낅젰?섏꽭??',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PopqSpacing.sm),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.expectedPhrase,
            ),
            onChanged: (value) {
              setState(() {
                _matchesPhrase = _stripSpaces(value) ==
                    _stripSpaces(widget.expectedPhrase);
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('痍⑥냼'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _SellerWithdrawDialogResult(immediate: false),
          ),
          child: const Text('7?????덊눜'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _matchesPhrase
              ? () => Navigator.of(context).pop(
                    const _SellerWithdrawDialogResult(immediate: true),
                  )
              : null,
          child: const Text('吏湲?諛붾줈 ?덊눜'),
        ),
      ],
    );
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
                  store?.name ?? '?좏깮???ъ뾽?μ씠 ?놁뼱??,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  store == null
                      ? '??쒕낫?쒖뿉???ъ뾽?μ쓣 ?좏깮??二쇱꽭??'
                      : '${_roleLabel(store.myRole)} 쨌 '
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

String _stripSpaces(String value) => value.replaceAll(RegExp(r'\s+'), '');

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
                      'POPQ 怨좉컼 臾몄쓽',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: PopqSpacing.xs),
                    Text(
                      '怨좉컼 臾몄쓽? ?쎌? ?딆? 硫붿떆吏瑜??뺤씤?섏꽭??',
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
    'OWNER' => '?ъ뾽??,
    'MANAGER' => '留ㅻ땲?',
    'STAFF' => '吏곸썝',
    _ => role,
  };
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '?곸뾽 以?,
    'PRE_OPEN' => '?곸뾽 以鍮?,
    'CLOSED' => '?곸뾽 醫낅즺',
    _ => status,
  };
}

