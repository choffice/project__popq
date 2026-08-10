import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/customer_realtime_scope.dart';
import '../../routing/customer_router.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_engagement_repository.dart';

/// 留덉씠?섏씠吏 ?곷떒 移대뱶???쒖떆?섎뒗 ?깃툒쨌?쒕룞 ?듦퀎?낅땲??
///
/// ?덈꺼, 諛⑸Ц ?잛닔, 蹂댁쑀 ?ъ씤?몃뒗 ?꾩쭅 諛깆뿏?쒖뿉
/// 愿??API媛 ?놁뼱 ?붾㈃ ?붿옄???뺤씤???꾩떆媛믪엯?덈떎.
/// ?ㅼ젣 API媛 以鍮꾨릺硫?[CustomerProfile]???꾨뱶瑜?異붽???援먯껜?⑸땲??
abstract final class _ProfileTemporaryStats {
  static const levelLabel = 'Lv.12';
  static const visitCount = 37;
  static const pointLabel = '2,450P';
  static const locationLabel = '?꾩튂 ?뺣낫瑜??ㅼ젙??蹂댁꽭??;
}

/// 媛?낆씪遺???ㅻ뒛源뚯????쇱닔瑜?"?앺걧? ?④퍡?쒖? n?쇱㎏"濡??쒖떆?⑸땲??
/// 媛?낆씪 ?뺣낫媛 ?놁쑝硫??? 硫붾え由???μ냼) ?쇰컲?곸씤 臾멸뎄濡??泥댄빀?덈떎.
String _daysTogetherLabel(CustomerProfile profile) {
  final days = profile.daysSinceJoined;
  if (days == null) {
    return '?앺걧? ?④퍡?섍퀬 ?덉뼱??;
  }
  return '?앺걧? ?④퍡?쒖? $days?쇱㎏';
}

const _dangerColor = Color(0xFFE5484D);

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    required this.repository,
    required this.messageRepository,
    required this.onSignOut,
    required this.onConnectSellerAccess,
    required this.onWithdraw,
    super.key,
  });

  final CustomerEngagementRepository repository;
  final CustomerOrderMessageRepository messageRepository;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onConnectSellerAccess;
  final Future<void> Function(String? confirmationPhrase) onWithdraw;

  @override
  State<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState
    extends State<CustomerProfileScreen>
    with WidgetsBindingObserver {
  static const Duration _unreadPollingInterval =
  Duration(seconds: 3);

  late Future<CustomerProfile> _profile;

  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingProfileImage = false;

  Timer? _unreadPollingTimer;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _customerChatSubscription;

  int _unreadMessageCount = 0;
  int _requestGeneration = 0;
  int _observedConnectionEpoch = 0;

  bool _unreadRequestInProgress = false;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;

    _profile = widget.repository.getProfile();

    unawaited(
      _refreshUnreadMessageCount(),
    );
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

    _syncUnreadPollingWithRealtime();
  }

  @override
  void didUpdateWidget(
      covariant CustomerProfileScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository) {
      setState(() {
        _profile = widget.repository.getProfile();
      });
    }

    if (oldWidget.messageRepository !=
        widget.messageRepository) {
      _requestGeneration++;

      unawaited(
        _refreshUnreadMessageCount(),
      );
    }

    _syncUnreadPollingWithRealtime();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      _syncUnreadPollingWithRealtime();

      unawaited(
        _refreshUnreadMessageCount(),
      );

      return;
    }

    _isAppActive = false;
    _stopUnreadPolling();
  }

  @override
  void dispose() {
    _requestGeneration++;

    _stopUnreadPolling();

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );
    _realtimeClient = null;

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const PopqLoadingView(
            message: '留덉씠?섏씠吏瑜?遺덈윭?ㅺ퀬 ?덉뼱??',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '留덉씠?섏씠吏瑜?遺덈윭?ㅼ? 紐삵뻽?댁슂.',
            onRetry: _reload,
          );
        }

        final profile = snapshot.requireData;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: [
              _ProfileHeaderCard(
                profile: profile,
                onEditProfile: _editProfileImage,
                isUploadingImage: _uploadingProfileImage,
              ),

              const SizedBox(
                height: PopqSpacing.lg,
              ),

              _MenuGroupCard(
                rows: [
                  _MenuRowData(
                    icon: Icons.person_outline_rounded,
                    title: '???뺣낫',
                    subtitle:
                    '?꾨줈???ъ쭊, ?곕씫泥? 鍮꾨?踰덊샇瑜?愿由ы빐??,
                    onTap: () {
                      context.push(
                        CustomerRoutes.myInfo,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon:
                    Icons.confirmation_number_outlined,
                    title: '?덉빟 ?댁뿭',
                    subtitle: _unreadMessageCount > 0
                        ? '留ㅼ옣?먯꽌 蹂대궦 ???듬???'
                        '$_unreadMessageCount媛??덉뼱??
                        : '?덈ℓ???대깽?몄? ?덉빟 ?뺣낫瑜??뺤씤?댁슂',
                    badgeCount: _unreadMessageCount,
                    onTap: () {
                      context.push(
                        CustomerRoutes.orders,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.history_rounded,
                    title: '諛⑸Ц 湲곕줉',
                    subtitle:
                    '諛⑸Ц?덈뜕 留ㅼ옣 湲곕줉???뺤씤?댁슂',
                    onTap: () {
                      context.push(
                        CustomerRoutes.visitHistory,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.edit_note_rounded,
                    title: '??由щ럭',
                    subtitle:
                    '?닿? ?묒꽦??由щ럭瑜?紐⑥븘遊ㅼ뼱??,
                    onTap: () {
                      context.push(
                        CustomerRoutes.myReviews,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.star_border_rounded,
                    title: '?ъ씤???댁뿭',
                    subtitle:
                    '?ъ씤???곷┰ 諛??ъ슜 ?댁뿭???뺤씤?댁슂',
                    onTap: _showComingSoon,
                  ),
                  _MenuRowData(
                    icon:
                    Icons.notifications_none_rounded,
                    title: '?뚮┝ ?ㅼ젙',
                    subtitle:
                    '?몄떆 ?뚮┝ 諛?留덉????섏떊 ?ㅼ젙??愿由ы빐??,
                    onTap: () {
                      context.push(
                        CustomerRoutes.notificationSettings,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.help_outline_rounded,
                    title: '怨좉컼?쇳꽣',
                    subtitle:
                    '?먯＜ 臾삳뒗 吏덈Ц怨?1:1 臾몄쓽瑜??????덉뼱??,
                    onTap: _showComingSoon,
                  ),
                  _MenuRowData(
                    icon: Icons.storefront_rounded,
                    title: '?앺걧 鍮꾩쫰 ?곌껐?섍린',
                    subtitle:
                    '??怨꾩젙?쇰줈 ?먮ℓ??(?앺걧 鍮꾩쫰) ?쒕퉬?ㅻ룄 ?댁슜?섏꽭??,
                    onTap: _connectSellerAccess,
                  ),
                ],
              ),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              _MenuGroupCard(
                rows: [
                  _MenuRowData(
                    icon: Icons.logout_rounded,
                    title: '濡쒓렇?꾩썐',
                    subtitle: '?앺걧 怨꾩젙?먯꽌 濡쒓렇?꾩썐?댁슂',
                    color: _dangerColor,
                    onTap: _signOut,
                  ),
                  _MenuRowData(
                    icon: Icons.warning_amber_rounded,
                    title: '?뚯썝 ?덊눜',
                    subtitle:
                    '?뚯썝 ?덊눜 ??紐⑤뱺 ?뺣낫媛 ??젣?쇱슂',
                    color: _dangerColor,
                    onTap: () => _withdraw(profile.name),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reload() async {
    final nextProfile =
    widget.repository.getProfile();

    setState(() {
      _profile = nextProfile;
    });

    await Future.wait<void>([
      nextProfile.then<void>((_) {}),
      _refreshUnreadMessageCount(),
    ]);
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

      // ?ъ뿰寃?吏곹썑 ?볦튇 unread 蹂?붾? REST濡???踰?蹂듦뎄?⑸땲??
      unawaited(
        _refreshUnreadMessageCount(),
      );
    }

    _syncUnreadPollingWithRealtime();
  }

  void _handleCustomerChatEvent(
    PopqRealtimeEvent event,
  ) {
    final shouldRefresh =
        event.isMessageRead ||
        (event.isMessageCreated &&
            event.message?.sentBySeller == true);

    if (!shouldRefresh) {
      return;
    }

    unawaited(
      _refreshUnreadMessageCount(),
    );
  }

  void _handleCustomerChatError(
    Object error,
  ) {
    debugPrint(
      '留덉씠 ?붾㈃ ?ㅼ떆媛?梨꾪똿 ?대깽?몃? 泥섎━?섏? 紐삵뻽?듬땲?? $error',
    );
  }

  void _syncUnreadPollingWithRealtime() {
    if (!_isAppActive) {
      _stopUnreadPolling();
      return;
    }

    if (_realtimeClient?.isConnected == true) {
      _stopUnreadPolling();
      return;
    }

    _startUnreadPolling();
  }

  void _startUnreadPolling() {
    if (!_isAppActive ||
        _realtimeClient?.isConnected == true ||
        (_unreadPollingTimer?.isActive ?? false)) {
      return;
    }

    _unreadPollingTimer = Timer.periodic(
      _unreadPollingInterval,
      (_) {
        unawaited(
          _refreshUnreadMessageCount(),
        );
      },
    );
  }

  void _stopUnreadPolling() {
    _unreadPollingTimer?.cancel();
    _unreadPollingTimer = null;
  }

  Future<void> _refreshUnreadMessageCount() async {
    if (!mounted || _unreadRequestInProgress) {
      return;
    }

    final generation = _requestGeneration;

    _unreadRequestInProgress = true;

    try {
      final unreadCounts =
      await widget.messageRepository
          .findUnreadMessageCounts();

      final totalUnreadCount =
      unreadCounts.fold<int>(
        0,
            (total, item) =>
        total + item.unreadCount,
      );

      if (!mounted ||
          generation != _requestGeneration ||
          totalUnreadCount ==
              _unreadMessageCount) {
        return;
      }

      setState(() {
        _unreadMessageCount =
            totalUnreadCount;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '?덉빟 ?댁뿭???쎌? ?딆? ?듬? ?섎? '
            '遺덈윭?ㅼ? 紐삵뻽?듬땲?? $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRequestInProgress = false;
    }
  }

  Future<void> _connectSellerAccess() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?앺걧 鍮꾩쫰 ?곌껐?섍린'),
        content: const Text(
          '??怨꾩젙?쇰줈 ?먮ℓ???앺걧 鍮꾩쫰) ?쒕퉬?ㅻ룄 ?댁슜?????덇쾶 ?곌껐?좉퉴??\n'
          '?곌껐 ?꾩뿉??媛숈? ?대찓?쇨낵 鍮꾨?踰덊샇濡??먮ℓ???깆뿉 濡쒓렇?명븷 ???덉뼱??',
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
      await widget.onConnectSellerAccess();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '?앺걧 鍮꾩쫰 ?곌껐???꾨즺?먯뼱?? 媛숈? 怨꾩젙?쇰줈 ?먮ℓ???깆뿉 濡쒓렇?명빐 蹂댁꽭??',
            ),
          ),
        );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(content: Text(failure.message)),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text('?앺걧 鍮꾩쫰 ?곌껐???ㅽ뙣?덉뼱?? ($error)'),
          ),
        );
    }
  }

  Future<void> _editProfileImage() async {
    if (_uploadingProfileImage) return;

    final PopqImageSource? source =
        await showPopqImageSourceSheet(context);
    if (source == null || !mounted) return;

    final ImageSource pickerSource = source == PopqImageSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: pickerSource,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text(
              pickerSource == ImageSource.camera
                  ? '移대찓?쇰? ?ㅽ뻾?섏? 紐삵뻽?듬땲??'
                  : '媛ㅻ윭由ъ뿉???ъ쭊??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
            ),
          ),
        );
      return;
    }

    if (image == null || !mounted) return;

    setState(() => _uploadingProfileImage = true);
    try {
      await widget.repository.uploadProfileImage(image.path);

      if (!mounted) return;
      await _reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(content: Text('?꾨줈???ъ쭊??蹂寃쎈릱?댁슂.')),
        );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(content: Text(failure.message)),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(content: Text('?꾨줈???ъ쭊??蹂寃쏀븯吏 紐삵뻽?댁슂. ($error)')),
        );
    } finally {
      if (mounted) {
        setState(() => _uploadingProfileImage = false);
      }
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(
        const SnackBar(
          content: Text('以鍮?以묒씤 湲곕뒫?댁뿉??'),
        ),
      );
  }

  Future<void> _signOut() async {
    await widget.onSignOut();

    if (mounted) {
      context.go(CustomerRoutes.home);
    }
  }

  Future<void> _withdraw(String memberName) async {
    final expectedPhrase = '$memberName / ?덊눜?섍쿋?듬땲??;

    final result = await showDialog<_WithdrawDialogResult>(
      context: context,
      builder: (context) => _WithdrawDialog(
        expectedPhrase: expectedPhrase,
      ),
    );

    if (result == null || !mounted) return;

    try {
      await widget.onWithdraw(
        result.immediate ? expectedPhrase : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text(
              result.immediate
                  ? '?덊눜媛 ?꾨즺?먯뼱??'
                  : '?덊눜媛 ?묒닔?먯뼱?? 7???덉뿉 ?ㅼ떆 濡쒓렇?명븯硫??덊눜媛 痍⑥냼?쇱슂.',
            ),
          ),
        );
      context.go(CustomerRoutes.home);
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(content: Text(failure.message)),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text('?뚯썝 ?덊눜???ㅽ뙣?덉뼱?? ($error)'),
          ),
        );
    }
  }
}

class _WithdrawDialogResult {
  const _WithdrawDialogResult({required this.immediate});

  final bool immediate;
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.expectedPhrase});

  final String expectedPhrase;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
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
            const _WithdrawDialogResult(immediate: false),
          ),
          child: const Text('7?????덊눜'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _dangerColor,
          ),
          onPressed: _matchesPhrase
              ? () => Navigator.of(context).pop(
                    const _WithdrawDialogResult(immediate: true),
                  )
              : null,
          child: const Text('吏湲?諛붾줈 ?덊눜'),
        ),
      ],
    );
  }
}

String _stripSpaces(String value) => value.replaceAll(RegExp(r'\s+'), '');

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.onEditProfile,
    this.isUploadingImage = false,
  });

  final CustomerProfile profile;
  final VoidCallback onEditProfile;
  final bool isUploadingImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.md,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: profile.profileImageUrl != null
                              ? NetworkImage(
                                  profile.profileImageUrl!,
                                )
                              : null,
                          child: profile.profileImageUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 34,
                                )
                              : null,
                        ),
                        if (isUploadingImage)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: isDark
                                ? PopqPalette.nightElevated
                                : PopqPalette.lightCard,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: onEditProfile,
                              customBorder:
                              const CircleBorder(),
                              child: Padding(
                                padding:
                                const EdgeInsets.all(
                                  5,
                                ),
                                child: Icon(
                                  Icons
                                      .photo_camera_rounded,
                                  size: 15,
                                  color: isDark
                                      ? PopqPalette.lime
                                      : PopqPalette
                                      .forest,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      width: PopqSpacing.md,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${profile.name}??,
                                  maxLines: 1,
                                  overflow: TextOverflow
                                      .ellipsis,
                                  style: theme
                                      .textTheme
                                      .titleLarge,
                                ),
                              ),
                              const SizedBox(
                                width: PopqSpacing.xs,
                              ),
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius
                                      .circular(999),
                                  border: Border.all(
                                    color: isDark
                                        ? PopqPalette
                                        .lime
                                        : PopqPalette
                                        .forest,
                                  ),
                                ),
                                child: Text(
                                  _ProfileTemporaryStats
                                      .levelLabel,
                                  style: theme
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                    color: isDark
                                        ? PopqPalette
                                        .lime
                                        : PopqPalette
                                        .forest,
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: PopqSpacing.xs,
                          ),
                          Text(
                            _daysTogetherLabel(profile),
                            style: theme
                                .textTheme.bodySmall
                                ?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons
                                    .location_on_outlined,
                                size: 15,
                                color: mutedColor,
                              ),
                              const SizedBox(
                                width: PopqSpacing.xs,
                              ),
                              Expanded(
                                child: Text(
                                  _ProfileTemporaryStats
                                      .locationLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow
                                      .ellipsis,
                                  style: theme
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: mutedColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? PopqPalette.nightBorder
                : PopqPalette.lightBorder,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: PopqSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon:
                    Icons.star_border_rounded,
                    label: '李쒗븳 ?대깽??,
                    value:
                    '${profile.interestCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons
                        .confirmation_number_outlined,
                    label: '李몄뿬???대깽??,
                    value:
                    '${profile.orderCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons
                        .calendar_today_outlined,
                    label: '諛⑸Ц ?잛닔',
                    value:
                    '${_ProfileTemporaryStats.visitCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons.paid_outlined,
                    label: '蹂댁쑀 ?ъ씤??,
                    value: _ProfileTemporaryStats
                        .pointLabel,
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({
    required this.isDark,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: isDark
          ? PopqPalette.nightBorder
          : PopqPalette.lightBorder,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final accent = isDark
        ? PopqPalette.lime
        : PopqPalette.forest;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return Column(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(height: PopqSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(
            color: highlight ? accent : null,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: mutedColor),
        ),
      ],
    );
  }
}

class _MenuRowData {
  const _MenuRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  final int badgeCount;
}

class _MenuGroupCard extends StatelessWidget {
  const _MenuGroupCard({
    required this.rows,
  });

  final List<_MenuRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0;
          index < rows.length;
          index++) ...[
            if (index > 0)
              const Divider(height: 1),
            _MenuRow(data: rows[index]),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.data,
  });

  final _MenuRowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    final foreground = data.color ??
        (isDark
            ? PopqPalette.lime
            : PopqPalette.forest);

    return ListTile(
      leading: Icon(data.icon, color: foreground),
      title: Text(
        data.title,
        style: theme.textTheme.titleMedium
            ?.copyWith(color: data.color),
      ),
      subtitle: Text(
        data.subtitle,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: mutedColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.badgeCount > 0) ...[
            _UnreadMessageBadge(
              count: data.badgeCount,
            ),
            const SizedBox(
              width: PopqSpacing.sm,
            ),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: mutedColor,
          ),
        ],
      ),
      onTap: data.onTap,
    );
  }
}


class _UnreadMessageBadge extends StatelessWidget {
  const _UnreadMessageBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.error,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 9 ? '9+' : count.toString(),
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
