import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/customer_realtime_scope.dart';
import '../../routing/customer_router.dart';
import '../discovery/customer_search_location_controller.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_engagement_repository.dart';

/// 마이페이지 상단 카드에 아직 API가 없는 임시 정보입니다.
abstract final class _ProfileTemporaryStats {
  static const levelLabel = 'Lv.12';
  static const visitCount = 37;
}

/// 가입일부터 오늘까지의 일수를 "팝큐와 함께한지 n일째"로 표시합니다.
/// 가입일 정보가 없으면(예: 메모리 저장소) 일반적인 문구로 대체합니다.
String _daysTogetherLabel(CustomerProfile profile) {
  final days = profile.daysSinceJoined;
  if (days == null) {
    return '팝큐와 함께하고 있어요';
  }
  return '팝큐와 함께한지 $days일째';
}

const _dangerColor = Color(0xFFE5484D);

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    required this.repository,
    required this.activitySummaryListenable,
    required this.messageRepository,
    this.searchLocationController,
    required this.onSignOut,
    required this.onConnectSellerAccess,
    required this.onWithdraw,
    super.key,
  });

  final CustomerEngagementRepository repository;
  final ValueListenable<CustomerActivitySummary?> activitySummaryListenable;
  final CustomerOrderMessageRepository messageRepository;
  final CustomerSearchLocationController? searchLocationController;
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
    widget.activitySummaryListenable.addListener(_handleActivitySummaryChanged);

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

    if (oldWidget.activitySummaryListenable !=
        widget.activitySummaryListenable) {
      oldWidget.activitySummaryListenable.removeListener(
        _handleActivitySummaryChanged,
      );
      widget.activitySummaryListenable.addListener(
        _handleActivitySummaryChanged,
      );
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

    widget.activitySummaryListenable.removeListener(
      _handleActivitySummaryChanged,
    );

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

  void _handleActivitySummaryChanged() {
    final summary = widget.activitySummaryListenable.value;
    if (summary == null || !mounted) return;

    setState(() {
      _profile = _profile.then(
        (profile) => profile.copyWith(activitySummary: summary),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const PopqLoadingView(
            message: '마이페이지를 불러오고 있어요.',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '마이페이지를 불러오지 못했어요.',
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
                searchLocationController: widget.searchLocationController,
              ),

              const SizedBox(
                height: PopqSpacing.lg,
              ),

              _MenuGroupCard(
                rows: [
                  _MenuRowData(
                    icon: Icons.person_outline_rounded,
                    title: '내 정보',
                    subtitle:
                    '프로필 사진, 연락처, 비밀번호를 관리해요',
                    onTap: () async {
                      await context.push(
                        CustomerRoutes.myInfo,
                      );
                      if (context.mounted) {
                        await _reload();
                      }
                    },
                  ),
                  _MenuRowData(
                    icon:
                    Icons.confirmation_number_outlined,
                    title: '주문 내역',
                    subtitle: _unreadMessageCount > 0
                        ? '매장에서 보낸 새 답변이 '
                        '$_unreadMessageCount개 있어요'
                        : '예매한 이벤트와 예약 정보를 확인해요',
                    badgeCount: _unreadMessageCount,
                    onTap: () {
                      context.push(
                        CustomerRoutes.orders,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.history_rounded,
                    title: '방문 기록',
                    subtitle:
                    '방문했던 매장 기록을 확인해요',
                    onTap: () {
                      context.push(
                        CustomerRoutes.visitHistory,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.edit_note_rounded,
                    title: '내 리뷰',
                    subtitle:
                    '내가 작성한 리뷰를 모아봤어요',
                    onTap: () {
                      context.push(
                        CustomerRoutes.myReviews,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.savings_outlined,
                    title: '포인트 내역',
                    subtitle: '결제로 적립하거나 환불로 회수된 내역을 확인해요',
                    onTap: () {
                      context.push(CustomerRoutes.pointHistory);
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.star_border_rounded,
                    title: '공지사항',
                    subtitle:
                    '버그 수정 / 업데이트 내역',
                    onTap: () {
                      context.push(CustomerRoutes.platformAnnouncements);
                    },
                  ),
                  _MenuRowData(
                    icon:
                    Icons.notifications_none_rounded,
                    title: '알림 설정',
                    subtitle:
                    '푸시 알림 및 마케팅 수신 설정을 관리해요',
                    onTap: () {
                      context.push(
                        CustomerRoutes.notificationSettings,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.help_outline_rounded,
                    title: '고객센터',
                    subtitle:
                    '자주 묻는 질문과 1:1 문의를 할 수 있어요',
                    onTap: () {
                      context.push(
                        CustomerRoutes.support,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.storefront_rounded,
                    title: '팝큐 비즈 연결하기',
                    subtitle:
                    '이 계정으로 판매자 (팝큐 비즈) 서비스도 이용하세요',
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
                    title: '로그아웃',
                    subtitle: '팝큐 계정에서 로그아웃해요',
                    color: _dangerColor,
                    onTap: _signOut,
                  ),
                  _MenuRowData(
                    icon: Icons.warning_amber_rounded,
                    title: '회원 탈퇴',
                    subtitle:
                    '회원 탈퇴 시 모든 정보가 삭제돼요',
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

      // 재연결 직후 놓친 unread 변화를 REST로 한 번 복구합니다.
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
      '마이 화면 실시간 채팅 이벤트를 처리하지 못했습니다: $error',
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
        '주문 내역의 읽지 않은 답변 수를 '
            '불러오지 못했습니다: $error',
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
        title: const Text('팝큐 비즈 연결하기'),
        content: const Text(
          '이 계정으로 판매자(팝큐 비즈) 서비스도 이용할 수 있게 연결할까요?\n'
          '연결 후에는 같은 이메일과 비밀번호로 판매자 앱에 로그인할 수 있어요.',
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
      await widget.onConnectSellerAccess();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '팝큐 비즈 연결이 완료됐어요. 같은 계정으로 판매자 앱에 로그인해 보세요.',
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
            content: Text('팝큐 비즈 연결에 실패했어요. ($error)'),
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
                  ? '카메라를 실행하지 못했습니다.'
                  : '갤러리에서 사진을 불러오지 못했습니다.',
            ),
          ),
        );
      return;
    }

    if (image == null || !mounted) return;

    setState(() => _uploadingProfileImage = true);
    try {
      if (kIsWeb) {
        await widget.repository.uploadProfileImageBytes(
          await image.readAsBytes(),
          fileName: image.name,
        );
      } else {
        await widget.repository.uploadProfileImage(image.path);
      }

      if (!mounted) return;
      await _reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(content: Text('프로필 사진이 변경됐어요.')),
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
          SnackBar(content: Text('프로필 사진을 변경하지 못했어요. ($error)')),
        );
    } finally {
      if (mounted) {
        setState(() => _uploadingProfileImage = false);
      }
    }
  }

  Future<void> _signOut() async {
    await widget.onSignOut();

    if (mounted) {
      context.go(CustomerRoutes.home);
    }
  }

  Future<void> _withdraw(String memberName) async {
    final expectedPhrase = '$memberName / 탈퇴하겠습니다';

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
                  ? '탈퇴가 완료됐어요.'
                  : '탈퇴가 접수됐어요. 7일 안에 다시 로그인하면 탈퇴가 취소돼요.',
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
            content: Text('회원 탈퇴에 실패했어요. ($error)'),
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
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _WithdrawDialogResult(immediate: false),
          ),
          child: const Text('7일 후 탈퇴'),
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
          child: const Text('지금 바로 탈퇴'),
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
    this.searchLocationController,
  });

  final CustomerProfile profile;
  final VoidCallback onEditProfile;
  final bool isUploadingImage;
  final CustomerSearchLocationController? searchLocationController;

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
                                  '${profile.name}님',
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
                              if (profile.emblemVisible &&
                                  profile.activitySummary
                                  .badgeAssetPath != null) ...[
                                Image.asset(
                                  profile.activitySummary
                                      .badgeAssetPath!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.contain,
                                  filterQuality:
                                  FilterQuality.high,
                                  semanticLabel: profile
                                      .activitySummary
                                      .badgeLabel,
                                ),
                                const SizedBox(
                                  width: PopqSpacing.xs,
                                ),
                              ],
                              if (profile.emblemVisible)
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
                                  profile.activitySummary
                                      .badgeLabel,
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
                                child: _ProfileLocationLabel(
                                  controller:
                                      searchLocationController,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PopqSpacing.md),
                _ActivityCheckpointProgress(
                  summary: profile.activitySummary,
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
                    label: '찜한 이벤트',
                    value:
                    '${profile.interestCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons
                        .confirmation_number_outlined,
                    label: '참여한 이벤트',
                    value:
                    '${profile.orderCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons
                        .calendar_today_outlined,
                    label: '누적 활동',
                    value: '${profile.activitySummary.totalCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLocationLabel extends StatelessWidget {
  const _ProfileLocationLabel({
    required this.controller,
    required this.color,
  });

  final CustomerSearchLocationController? controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final locationController = controller;

    if (locationController == null) {
      return _buildText(
        context,
        '위치 정보를 설정해 보세요',
      );
    }

    return AnimatedBuilder(
      animation: locationController,
      builder: (context, child) {
        final label = locationController.displayLabel.trim();

        return _buildText(
          context,
          label.isEmpty ? '위치 정보를 설정해 보세요' : label,
        );
      },
    );
  }

  Widget _buildText(
    BuildContext context,
    String label,
  ) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
    );
  }
}

class _ActivityCheckpointProgress extends StatelessWidget {
  const _ActivityCheckpointProgress({
    required this.summary,
  });

  final CustomerActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? PopqPalette.lime : PopqPalette.forest;
    final muted = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;
    final next = summary.nextCheckpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                next == null
                    ? '다이아 엠블럼을 달성했어요'
                    : '다음 체크포인트 ${summary.remainingCount}회',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              next == null ? '완료' : '${summary.remainingCount}회 남음',
              style: theme.textTheme.labelMedium?.copyWith(
                color: muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: PopqSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: summary.checkpointProgress.clamp(0.0, 1.0).toDouble(),
            backgroundColor: accent.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
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
