import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/customer_realtime_scope.dart';
import '../../routing/customer_router.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_order_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.orderPublicId,
    required this.repository,
    required this.messageRepository,
    super.key,
  });

  final String orderPublicId;
  final CustomerOrderRepository repository;
  final CustomerOrderMessageRepository messageRepository;

  @override
  State<OrderDetailScreen> createState() {
    return _OrderDetailScreenState();
  }
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  static const Duration _fallbackPollingInterval = Duration(
    seconds: 3,
  );

  CustomerOrder? _order;
  CustomerPaymentSummary? _paymentSummary;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _customerChatSubscription;
  PopqRealtimeSubscription? _customerOrderSubscription;
  Timer? _fallbackPollingTimer;

  Object? _error;

  var _unreadCount = 0;
  var _loading = true;
  var _syncing = false;
  var _canceling = false;
  var _unreadRequestInProgress = false;
  var _requestGeneration = 0;
  var _observedConnectionEpoch = 0;
  var _isAppActive = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;

    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient =
        CustomerRealtimeScope.of(context);

    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _customerOrderSubscription?.cancel();
    _customerOrderSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    _realtimeClient = nextRealtimeClient;
    _observedConnectionEpoch =
        nextRealtimeClient.connectionEpoch;

    nextRealtimeClient.addListener(
      _handleRealtimeClientChanged,
    );

    _customerChatSubscription =
        nextRealtimeClient.subscribeToCustomerChat(
      onEvent: _handleCustomerChatEvent,
      onError: _handleCustomerChatError,
    );

    _customerOrderSubscription =
        nextRealtimeClient.subscribeToCustomerOrders(
      onEvent: _handleCustomerOrderEvent,
      onError: _handleCustomerOrderError,
    );

    _syncFallbackPollingWithRealtime();
  }

  @override
  void didUpdateWidget(
      covariant OrderDetailScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orderPublicId != widget.orderPublicId ||
        oldWidget.repository != widget.repository ||
        oldWidget.messageRepository !=
            widget.messageRepository) {
      _requestGeneration++;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _syncFallbackPollingWithRealtime();

        unawaited(
          _recoverLatestState(),
        );

        return;

      case AppLifecycleState.inactive:
        _isAppActive = false;
        _stopFallbackPolling();
        return;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _stopFallbackPolling();
        return;
    }
  }

  @override
  void dispose() {
    _requestGeneration++;

    WidgetsBinding.instance.removeObserver(this);

    _stopFallbackPolling();

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _customerOrderSubscription?.cancel();
    _customerOrderSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );
    _realtimeClient = null;

    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(CustomerRoutes.orders);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) {
        if (didPop) {
          return;
        }

        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: '?ㅻ줈媛湲?,
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),
          title: const Text('二쇰Ц ?곸꽭'),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(
        message: '理쒖떊 二쇰Ц ?곹깭瑜??뺤씤?섍퀬 ?덉뼱??',
      );
    }

    if (_error != null || _order == null) {
      return PopqErrorView(
        message: '二쇰Ц ?곸꽭瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??',
        onRetry: _load,
      );
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: PopqPalette.forest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: PopqPalette.lime,
                  size: 48,
                ),
                const SizedBox(
                  height: PopqSpacing.sm,
                ),
                Text(
                  _statusLabel(order.status),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(
                  height: PopqSpacing.xs,
                ),
                Text(
                  order.storeName,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: PopqSpacing.lg,
          ),

          _OrderNumberSection(
            orderPublicId: order.orderPublicId,
          ),

          if (_latestCancellationHistory(order) case final history?) ...[
            const SizedBox(height: PopqSpacing.sm),
            _CancellationInfoSection(
              orderStatus: order.status,
              history: history,
            ),
          ],

          if (order.preparationMinutes != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(
                  order.preparationMinutes == 0
                      ? '?곹뭹??諛붾줈 以鍮꾪빐??
                      : '?덉긽 以鍮꾩떆媛?${order.preparationMinutes}遺?,
                ),
                subtitle: order.estimatedReadyAt == null
                    ? null
                    : Text(
                        '?덉긽 ?꾨즺 ${_formatEstimatedTime(order.estimatedReadyAt!)}',
                      ),
              ),
            ),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          Text(
            '二쇰Ц ?곹뭹',
            style:
            Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),

          for (final item in order.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.productName,
              ),
              subtitle: Text(
                '${item.quantity}媛?,
              ),
              trailing: Text(
                _won(item.itemTotalPrice),
              ),
            ),

          const Divider(),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '珥?寃곗젣 湲덉븸',
            ),
            trailing: Text(
              _won(order.totalAmount),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          if (_paymentSummary case final payment?) ...[
            const SizedBox(height: PopqSpacing.md),
            _PaymentRefundSection(
              payment: payment,
            ),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          _InquirySection(
            unreadCount: _unreadCount,
            onPressed: _openInquiry,
          ),

          if (order.status == 'PLACED') ...[
            const SizedBox(
              height: PopqSpacing.lg,
            ),
            _CustomerCancelSection(
              canceling: _canceling,
              onPressed: _cancelOrder,
            ),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          if (order.status == 'COMPLETED') ...[
            FilledButton.icon(
              onPressed: () async {
                final created =
                await context.push<bool>(
                  '${CustomerRoutes.orders}/'
                      '${order.orderPublicId}/review',
                );

                if (!mounted) {
                  return;
                }

                if (created == true) {
                  ScaffoldMessenger.of(context)
                      .showTopSnackBar(
                    const SnackBar(
                      content: Text(
                        '由щ럭瑜??깅줉?덉뼱??',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.rate_review_rounded,
              ),
              label: const Text(
                '由щ럭 ?묒꽦',
              ),
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
          ],

          OutlinedButton.icon(
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.sync_rounded,
            ),
            label: Text(
              _syncing
                  ? '?뺤씤 以?..'
                  : '理쒖떊 ?곹깭 ?뺤씤',
            ),
          ),

          const SizedBox(
            height: PopqSpacing.sm,
          ),

          Text(
            '?쒕쾭 踰꾩쟾 ${order.version} 쨌 '
                '?뚮┝ ?섏떊 ?꾩뿉????API濡?理쒖떊 ?곹깭瑜?'
                '?ㅼ떆 ?뺤씤?⑸땲??',
            textAlign: TextAlign.center,
            style:
            Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatEstimatedTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hour:$minute';
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );
      final unreadCount = await _findUnreadCount();
      final paymentSummary = await _findPaymentSummary(order);

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _paymentSummary = paymentSummary;
        _unreadCount = unreadCount ?? 0;
        _loading = false;
        _error = null;
      });
    } catch (caught) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _error = caught;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final generation = _requestGeneration;

    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );
      final unreadCount = await _findUnreadCount();
      final paymentSummary = await _findPaymentSummary(order);

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );

        if (paymentSummary != null) {
          _paymentSummary = paymentSummary;
        }

        if (unreadCount != null) {
          _unreadCount = unreadCount;
        }

        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '理쒖떊 二쇰Ц ?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??',
          ),
        ),
      );
    }
  }

  Future<void> _refreshOrderSilently() async {
    final generation = _requestGeneration;

    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '二쇰Ц ?곸꽭 理쒖떊 ?곹깭瑜??먮룞 蹂듦뎄?섏? 紐삵뻽?듬땲?? $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncOrderAfterRealtimeEvent({
    required int knownVersion,
  }) async {
    final generation = _requestGeneration;

    try {
      final result = await widget.repository.sync(
        widget.orderPublicId,
        knownVersion,
      );
      final serverOrder = result.order;

      if (!mounted ||
          generation != _requestGeneration ||
          serverOrder == null) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: serverOrder,
        );
        _error = null;
      });

      await _refreshPaymentSummary();
    } catch (error, stackTrace) {
      // status/version? ?ㅼ떆媛??대깽?몄뿉???대? 諛섏쁺?덉뒿?덈떎.
      // 以鍮꾩떆媛?媛숈? ?섎㉧吏 ?꾨뱶???ъ뿰寃?fallback REST 議고쉶?먯꽌
      // ?ㅼ떆 蹂듦뎄?⑸땲??
      debugPrint(
        '二쇰Ц ?곸꽭 ?ㅼ떆媛??대깽????REST ?숆린?붿뿉 ?ㅽ뙣?덉뒿?덈떎: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _recoverLatestState() async {
    await Future.wait<void>(<Future<void>>[
      _refreshOrderSilently(),
      _refreshPaymentSummary(),
      _refreshUnreadCount(),
    ]);
  }

  Future<void> _sync() async {
    final current = _order;

    if (current == null || _syncing) {
      return;
    }

    setState(() {
      _syncing = true;
    });

    try {
      final result = await widget.repository.sync(
        current.orderPublicId,
        current.version,
      );

      final unreadCount =
      await _findUnreadCount();
      final syncOrder = result.order ?? current;
      final paymentSummary = await _findPaymentSummary(syncOrder);

      if (!mounted) {
        return;
      }

      setState(() {
        if (result.order != null) {
          _order = _newerOrder(
            current: _order,
            candidate: result.order!,
          );
        }

        if (paymentSummary != null) {
          _paymentSummary = paymentSummary;
        }

        if (unreadCount != null) {
          _unreadCount = unreadCount;
        }

        _syncing = false;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            result.refreshRequired
                ? '理쒖떊 二쇰Ц ?곹깭濡?媛깆떊?덉뒿?덈떎.'
                : '?대? 理쒖떊 ?곹깭?낅땲??',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _syncing = false;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '理쒖떊 ?곹깭瑜??뺤씤?섏? 紐삵뻽?듬땲??',
          ),
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final order = _order;

    if (order == null ||
        order.status != 'PLACED' ||
        _canceling) {
      return;
    }

    final reason = await _showCancelReasonSheet();

    if (!mounted || reason == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('二쇰Ц??痍⑥냼?섏떆寃좎뼱??'),
          content: Text(
            '痍⑥냼 ?ъ쑀: $reason\n\n'
            '?먮ℓ?먭? ?꾩쭅 ?묒닔?섏? ?딆? 二쇰Ц留?痍⑥냼?????덉쑝硫? '
            '痍⑥냼媛 ?꾨즺?섎㈃ 寃곗젣 湲덉븸???꾩븸 ?섎텋 泥섎━?⑸땲??',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('?뚯븘媛湲?),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('二쇰Ц 痍⑥냼'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _canceling = true;
    });

    try {
      final canceled = await widget.repository.cancel(
        order.orderPublicId,
        reason: reason,
      );
      final paymentSummary = await _findPaymentSummary(canceled);

      if (!mounted) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: canceled,
        );

        if (paymentSummary != null) {
          _paymentSummary = paymentSummary;
        }

        _canceling = false;
        _error = null;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '二쇰Ц??痍⑥냼?덇퀬 寃곗젣 湲덉븸???섎텋 泥섎━?덉뼱??',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('怨좉컼 二쇰Ц 痍⑥냼???ㅽ뙣?덉뒿?덈떎: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _canceling = false;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '二쇰Ц??痍⑥냼?섏? 紐삵뻽?듬땲?? ?먮ℓ?먭? ?대? ?묒닔?덇굅???섎텋 泥섎━???ㅽ뙣?덉쓣 ???덉뼱??',
          ),
        ),
      );

      await _refresh();
    }
  }

  Future<String?> _showCancelReasonSheet() async {
    const otherValue = '__OTHER__';
    const reasons = <String>[
      '二쇰Ц???섎せ?덉뼱??,
      '?ㅻⅨ 硫붾돱濡?蹂寃쏀븯怨??띠뼱??,
      '湲곕떎由ш린 ?대젮?뚯슂',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.lg,
              PopqSpacing.sm,
              PopqSpacing.lg,
              PopqSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '痍⑥냼 ?ъ쑀瑜??좏깮?댁＜?몄슂',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  '?좏깮???ъ쑀???먮ℓ?먯뿉寃뚮룄 ?쒖떆?⑸땲??',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: PopqSpacing.md),
                for (final reason in reasons)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle_outlined),
                    title: Text(reason),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(reason),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('湲고?'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(otherValue),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return null;
    }

    if (selected != otherValue) {
      return selected;
    }

    return _showCustomCancelReasonDialog();
  }

  Future<String?> _showCustomCancelReasonDialog() async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('痍⑥냼 ?ъ쑀 ?낅젰'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '痍⑥냼 ?ъ쑀瑜??낅젰?댁＜?몄슂.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('?リ린'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();

                  if (value.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('?좏깮'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openInquiry() async {
    final order = _order;

    if (order == null) {
      return;
    }

    await context.push(
      CustomerRoutes.orderMessages(
        order.orderPublicId,
      ),
    );

    if (!mounted) {
      return;
    }

    /*
     * 梨꾪똿 ?붾㈃?먯꽌 ?먮ℓ???듬???議고쉶?섎㈃
     * 諛깆뿏?쒓? ?대떦 硫붿떆吏瑜??쎌쓬 泥섎━?⑸땲??
     *
     * ?붾㈃ 蹂듦? 利됱떆 諛곗?瑜??쒓굅????
     * ?쒕쾭??理쒖떊 二쇰Ц 諛??쎌? ?딆? 媛쒖닔瑜??ㅼ떆 ?뺤씤?⑸땲??
     */
    setState(() {
      _unreadCount = 0;
    });

    await _refreshAfterInquiry();
  }

  Future<void> _refreshAfterInquiry() async {
    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );

      final unreadCount =
      await _findUnreadCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _unreadCount = unreadCount ?? 0;
        _error = null;
      });
    } catch (_) {
      /*
       * 梨꾪똿 ?붾㈃?먯꽌 ?뺤긽?곸쑝濡??뚯븘??寃쎌슦?먮뒗
       * 二쇰Ц ?곸꽭 ?붾㈃???ㅻ쪟 ?붾㈃?쇰줈 諛붽씀吏 ?딆뒿?덈떎.
       */
    }
  }

  Future<CustomerPaymentSummary?> _findPaymentSummary(
    CustomerOrder order,
  ) async {
    if (order.status == 'CREATED') {
      return null;
    }

    try {
      return await widget.repository.findPaymentSummary(
        order.orderPublicId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '二쇰Ц ?곸꽭 寃곗젣/?섎텋 ?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲?? $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _refreshPaymentSummary() async {
    final order = _order;

    if (!mounted || order == null) {
      return;
    }

    final generation = _requestGeneration;
    final paymentSummary = await _findPaymentSummary(order);

    if (!mounted ||
        generation != _requestGeneration ||
        paymentSummary == null) {
      return;
    }

    setState(() {
      _paymentSummary = paymentSummary;
    });
  }

  Future<int?> _findUnreadCount() async {
    try {
      final counts = await widget.messageRepository
          .findUnreadMessageCounts();

      for (final item in counts) {
        if (item.orderPublicId ==
            widget.orderPublicId) {
          return item.unreadCount;
        }
      }

      return 0;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshUnreadCount() async {
    if (!mounted || _unreadRequestInProgress) {
      return;
    }

    final generation = _requestGeneration;
    _unreadRequestInProgress = true;

    try {
      final unreadCount = await _findUnreadCount();

      if (!mounted ||
          generation != _requestGeneration ||
          unreadCount == null ||
          unreadCount == _unreadCount) {
        return;
      }

      setState(() {
        _unreadCount = unreadCount;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '二쇰Ц ?곸꽭???쎌? ?딆? ?듬? ?섎? 媛깆떊?섏? 紐삵뻽?듬땲?? $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRequestInProgress = false;
    }
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      return;
    }

    if (_observedConnectionEpoch !=
        realtimeClient.connectionEpoch) {
      _observedConnectionEpoch =
          realtimeClient.connectionEpoch;

      // ?ъ뿰寃?吏곹썑 ?딄릿 ?숈븞 ?볦튇 二쇰Ц ?곹깭? 臾몄쓽 諛곗?瑜?
      // REST濡??ㅼ떆 議고쉶?⑸땲??
      unawaited(
        _recoverLatestState(),
      );
    }

    _syncFallbackPollingWithRealtime();
  }

  void _handleCustomerOrderEvent(
    PopqOrderRealtimeEvent event,
  ) {
    if (event.orderPublicId != widget.orderPublicId) {
      return;
    }

    final currentOrder = _order;

    if (currentOrder == null) {
      unawaited(
        _refreshOrderSilently(),
      );
      return;
    }

    if (event.isDuplicateOrOlderThan(currentOrder.version)) {
      return;
    }

    final knownVersion = currentOrder.version;

    setState(() {
      _order = currentOrder.applyRealtimeEvent(event);
      _error = null;
    });

    // ?붾㈃?먮뒗 利됱떆 ?곹깭瑜?蹂댁뿬二쇨퀬, ?대깽?몄뿉 ?ы븿?섏? ?딆?
    // 以鍮꾩떆媛??덉긽?꾨즺?쒓컙 ?깆? REST sync濡?蹂댁젙?⑸땲??
    unawaited(
      _syncOrderAfterRealtimeEvent(
        knownVersion: knownVersion,
      ),
    );
  }

  void _handleCustomerOrderError(
    Object error,
  ) {
    debugPrint(
      '二쇰Ц ?곸꽭 ?ㅼ떆媛??곹깭 ?대깽?몃? 泥섎━?섏? 紐삵뻽?듬땲?? $error',
    );
  }

  void _handleCustomerChatEvent(
    PopqRealtimeEvent event,
  ) {
    if (event.orderPublicId != widget.orderPublicId) {
      return;
    }

    final shouldRefresh =
        event.isMessageRead ||
        (event.isMessageCreated &&
            event.message?.sentBySeller == true);

    if (!shouldRefresh) {
      return;
    }

    unawaited(
      _refreshUnreadCount(),
    );
  }

  void _handleCustomerChatError(
    Object error,
  ) {
    debugPrint(
      '二쇰Ц ?곸꽭 ?ㅼ떆媛?梨꾪똿 ?대깽?몃? 泥섎━?섏? 紐삵뻽?듬땲?? $error',
    );
  }

  void _syncFallbackPollingWithRealtime() {
    if (!_isAppActive) {
      _stopFallbackPolling();
      return;
    }

    if (_realtimeClient?.isConnected == true) {
      _stopFallbackPolling();
      return;
    }

    _startFallbackPolling();
  }

  void _startFallbackPolling() {
    if (!_isAppActive ||
        _realtimeClient?.isConnected == true ||
        (_fallbackPollingTimer?.isActive ?? false)) {
      return;
    }

    _fallbackPollingTimer = Timer.periodic(
      _fallbackPollingInterval,
      (_) {
        unawaited(
          _recoverLatestState(),
        );
      },
    );
  }

  void _stopFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
  }
  CustomerOrder _newerOrder({
    required CustomerOrder? current,
    required CustomerOrder candidate,
  }) {
    if (current != null && current.version > candidate.version) {
      return current;
    }

    return candidate;
  }
}

CustomerOrderStatusHistory? _latestCancellationHistory(
  CustomerOrder order,
) {
  for (final history in order.statusHistory.reversed) {
    if (history.isCancellationOrRejection) {
      return history;
    }
  }

  return null;
}

class _CancellationInfoSection extends StatelessWidget {
  const _CancellationInfoSection({
    required this.orderStatus,
    required this.history,
  });

  final String orderStatus;
  final CustomerOrderStatusHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRejected = orderStatus == 'REJECTED';
    final reason = history.reason?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected
                    ? Icons.block_rounded
                    : Icons.cancel_outlined,
                color: colorScheme.error,
              ),
              const SizedBox(width: PopqSpacing.sm),
              Text(
                isRejected ? '二쇰Ц 嫄곗젅 ?뺣낫' : '二쇰Ц 痍⑥냼 ?뺣낫',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.md),
          _InfoRow(
            label: isRejected ? '嫄곗젅 二쇱껜' : '痍⑥냼 二쇱껜',
            value: _actorLabel(history.actorType),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: isRejected ? '嫄곗젅 ?ъ쑀' : '痍⑥냼 ?ъ쑀',
            value: reason == null || reason.isEmpty
                ? '?ъ쑀媛 ?깅줉?섏? ?딆븯?댁슂.'
                : reason,
            alignTop: true,
          ),
          if (history.changedAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: isRejected ? '嫄곗젅 ?쒓컙' : '痍⑥냼 ?쒓컙',
              value: _formatDateTime(history.changedAt!),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRefundSection extends StatelessWidget {
  const _PaymentRefundSection({
    required this.payment,
  });

  final CustomerPaymentSummary payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: PopqSpacing.sm),
              Text(
                '寃곗젣쨌?섎텋',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.md),
          _InfoRow(
            label: '寃곗젣 ?곹깭',
            value: _paymentStatusLabel(payment.paymentStatus),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '寃곗젣 ?섎떒',
            value: _paymentMethodLabel(payment.paymentMethod),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '寃곗젣 湲덉븸',
            value: _won(payment.approvedAmount),
          ),
          if (payment.refundedAmount > 0) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '?섎텋 湲덉븸',
              value: _won(payment.refundedAmount),
              valueStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (payment.approvedAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '寃곗젣 ?뱀씤',
              value: _formatDateTime(payment.approvedAt!),
            ),
          ],
          if (payment.canceledAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '寃곗젣 痍⑥냼',
              value: _formatDateTime(payment.canceledAt!),
            ),
          ],
          if (payment.refunds.isNotEmpty) ...[
            const SizedBox(height: PopqSpacing.md),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              '?섎텋 ?대젰',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: PopqSpacing.sm),
            for (var index = 0; index < payment.refunds.length; index++) ...[
              _RefundHistoryCard(
                index: index + 1,
                refund: payment.refunds[index],
              ),
              if (index != payment.refunds.length - 1)
                const SizedBox(height: PopqSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _RefundHistoryCard extends StatelessWidget {
  const _RefundHistoryCard({
    required this.index,
    required this.refund,
  });

  final int index;
  final CustomerRefundHistory refund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reason = refund.reason.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '?섎텋 $index',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _RefundStatusChip(status: refund.status),
            ],
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '?섎텋 湲덉븸',
            value: _won(refund.amount),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '泥섎━ 二쇱껜',
            value: _actorLabel(refund.requesterType),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '?섎텋 ?ъ쑀',
            value: reason.isEmpty ? '?ъ쑀媛 ?깅줉?섏? ?딆븯?댁슂.' : reason,
            alignTop: true,
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '?붿껌 ?쒓컙',
            value: _formatDateTime(refund.requestedAt),
          ),
          if (refund.completedAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '?꾨즺 ?쒓컙',
              value: _formatDateTime(refund.completedAt!),
            ),
          ],
          if (refund.status == 'FAILED' &&
              (refund.failureMessage?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '?ㅽ뙣 ?ъ쑀',
              value: refund.failureMessage!.trim(),
              alignTop: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _RefundStatusChip extends StatelessWidget {
  const _RefundStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = status == 'FAILED';
    final isSucceeded = status == 'SUCCEEDED';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isFailed
            ? colorScheme.errorContainer
            : isSucceeded
                ? colorScheme.primaryContainer
                : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _refundStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isFailed
              ? colorScheme.onErrorContainer
              : isSucceeded
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.alignTop = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final bool alignTop;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: PopqSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _OrderNumberSection extends StatelessWidget {
  const _OrderNumberSection({
    required this.orderPublicId,
  });

  final String orderPublicId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '二쇰Ц踰덊샇',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          SelectableText(
            formatPopqOrderNumber(orderPublicId),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InquirySection extends StatelessWidget {
  const _InquirySection({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUnreadMessage = unreadCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUnreadMessage
              ? colorScheme.error
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasUnreadMessage
                    ? Icons.mark_chat_unread_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: hasUnreadMessage
                    ? colorScheme.error
                    : colorScheme.primary,
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              Expanded(
                child: Text(
                  '1:1 臾몄쓽',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasUnreadMessage)
                _UnreadCountBadge(
                  unreadCount: unreadCount,
                ),
            ],
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          Text(
            hasUnreadMessage
                ? '留ㅼ옣?먯꽌 蹂대궦 ???듬????덉뼱??'
                : '二쇰Ц?대굹 ?곹뭹??沅곴툑???먯쓣 留ㅼ옣??臾몄쓽??蹂댁꽭??',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasUnreadMessage
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              fontWeight: hasUnreadMessage
                  ? FontWeight.w700
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.md,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.chat_rounded,
              ),
              label: Text(
                hasUnreadMessage
                    ? '???듬? ?뺤씤?섍린'
                    : '臾몄쓽?섍린',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCancelSection extends StatelessWidget {
  const _CustomerCancelSection({
    required this.canceling,
    required this.onPressed,
  });

  final bool canceling;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.error,
              ),
              const SizedBox(width: PopqSpacing.sm),
              Expanded(
                child: Text(
                  '二쇰Ц 痍⑥냼',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '?먮ℓ?먭? 二쇰Ц???묒닔?섍린 ?꾧퉴吏留?痍⑥냼?????덉뼱?? '
            '痍⑥냼媛 ?꾨즺?섎㈃ 寃곗젣 湲덉븸? ?꾩븸 ?섎텋?⑸땲??',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PopqSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canceling ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              icon: canceling
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.error,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(
                canceling ? '痍⑥냼 泥섎━ 以?..' : '二쇰Ц 痍⑥냼',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({
    required this.unreadCount,
  });

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 24,
        minHeight: 24,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        unreadCount > 99
            ? '99+'
            : unreadCount.toString(),
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

String _actorLabel(String actorType) {
  return switch (actorType) {
    'CUSTOMER' => '怨좉컼',
    'SELLER' => '?먮ℓ??,
    'ADMIN' => '愿由ъ옄',
    'SYSTEM' => '?쒖뒪??,
    'GUEST' => '鍮꾪쉶??怨좉컼',
    _ => actorType,
  };
}

String _paymentStatusLabel(String status) {
  return switch (status) {
    'READY' => '寃곗젣 以鍮?,
    'IN_PROGRESS' => '寃곗젣 ?뺤씤 以?,
    'PAID' => '寃곗젣 ?꾨즺',
    'PARTIALLY_REFUNDED' => '遺遺??섎텋',
    'REFUNDED' => '?섎텋 ?꾨즺',
    'CANCELED' => '寃곗젣 痍⑥냼',
    'FAILED' => '寃곗젣 ?ㅽ뙣',
    'EXPIRED' => '寃곗젣 留뚮즺',
    _ => status,
  };
}

String _paymentMethodLabel(String method) {
  return switch (method) {
    'CARD' => '移대뱶 / 媛꾪렪寃곗젣',
    'TEST' => '?뚯뒪??寃곗젣',
    _ => method,
  };
}

String _refundStatusLabel(String status) {
  return switch (status) {
    'REQUESTED' => '?섎텋 ?붿껌',
    'PROCESSING' => '?섎텋 泥섎━ 以?,
    'SUCCEEDED' => '?섎텋 ?꾨즺',
    'FAILED' => '?섎텋 ?ㅽ뙣',
    _ => status,
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}.$month.$day $hour:$minute';
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '寃곗젣 ?湲?,
    'PLACED' => '二쇰Ц ?묒닔 ?湲?,
    'ACCEPTED' => '二쇰Ц???묒닔?먯뼱??,
    'PREPARING' => '?곹뭹??以鍮꾪븯怨??덉뼱??,
    'READY' => '以鍮꾧? ?꾨즺?먯뼱??,
    'COMPLETED' => '二쇰Ц ?꾨즺',
    'REJECTED' => '二쇰Ц 嫄곗젅',
    'CANCELED' => '二쇰Ц 痍⑥냼',
    'EXPIRED' => '寃곗젣 留뚮즺',
    _ => status,
  };
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0;
  index < digits.length;
  index++) {
    if (index > 0 &&
        (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer??;
}

