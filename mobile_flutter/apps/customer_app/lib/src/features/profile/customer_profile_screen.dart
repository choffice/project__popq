import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/customer_realtime_scope.dart';
import '../../routing/customer_router.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_engagement_repository.dart';

/// 마이페이지 상단 카드에 표시하는 등급·활동 통계입니다.
///
/// 레벨, 함께한 일수, 방문 횟수, 보유 포인트는 아직 백엔드에
/// 관련 API가 없어 화면 디자인 확인용 임시값입니다.
/// 실제 API가 준비되면 [CustomerProfile]에 필드를 추가해 교체합니다.
abstract final class _ProfileTemporaryStats {
  static const levelLabel = 'Lv.12';
  static const daysTogetherLabel = '포포와 함께한지 128일째';
  static const visitCount = 37;
  static const pointLabel = '2,450P';
  static const locationLabel = '위치 정보를 설정해 보세요';
}

const _dangerColor = Color(0xFFE5484D);

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    required this.repository,
    required this.messageRepository,
    required this.onSignOut,
    required this.onConnectSellerAccess,
    super.key,
  });

  final CustomerEngagementRepository repository;
  final CustomerOrderMessageRepository messageRepository;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onConnectSellerAccess;

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
                onEditProfile: _showComingSoon,
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
                    '개인 정보 및 알림 설정을 관리해요',
                    onTap: _showComingSoon,
                  ),
                  _MenuRowData(
                    icon:
                    Icons.confirmation_number_outlined,
                    title: '예약 내역',
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
                    icon: Icons.favorite_border_rounded,
                    title: '찜한 이벤트',
                    subtitle:
                    '관심 있는 이벤트를 모아봤어요',
                    onTap: () {
                      context.go(
                        CustomerRoutes.favorites,
                      );
                    },
                  ),
                  _MenuRowData(
                    icon: Icons.history_rounded,
                    title: '최근 본 이벤트',
                    subtitle:
                    '최근에 본 이벤트를 확인해요',
                    onTap: _showComingSoon,
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
                    icon: Icons.star_border_rounded,
                    title: '포인트 내역',
                    subtitle:
                    '포인트 적립 및 사용 내역을 확인해요',
                    onTap: _showComingSoon,
                  ),
                  _MenuRowData(
                    icon: Icons.card_giftcard_rounded,
                    title: '이벤트 참여 내역',
                    subtitle:
                    '참여한 이벤트와 당첨 내역을 확인해요',
                    onTap: _showComingSoon,
                  ),
                  _MenuRowData(
                    icon:
                    Icons.notifications_none_rounded,
                    title: '알림 설정',
                    subtitle:
                    '푸시 알림 및 마케팅 수신 설정을 관리해요',
                    onTap: _showComingSoon,
                  ),
                  _MenuRowData(
                    icon: Icons.help_outline_rounded,
                    title: '고객센터',
                    subtitle:
                    '자주 묻는 질문과 1:1 문의를 할 수 있어요',
                    onTap: _showComingSoon,
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
                    subtitle: '포포 계정에서 로그아웃해요',
                    color: _dangerColor,
                    onTap: _signOut,
                  ),
                  _MenuRowData(
                    icon: Icons.warning_amber_rounded,
                    title: '회원 탈퇴',
                    subtitle:
                    '회원 탈퇴 시 모든 정보가 삭제돼요',
                    color: _dangerColor,
                    onTap: _showComingSoon,
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
        '예약 내역의 읽지 않은 답변 수를 '
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
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '팝큐 비즈 연결이 완료됐어요. 같은 계정으로 판매자 앱에 로그인해 보세요.',
            ),
          ),
        );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('팝큐 비즈 연결에 실패했어요. ($error)'),
          ),
        );
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('준비 중인 기능이에요.'),
        ),
      );
  }

  Future<void> _signOut() async {
    await widget.onSignOut();

    if (mounted) {
      context.go(CustomerRoutes.home);
    }
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.onEditProfile,
  });

  final CustomerProfile profile;
  final VoidCallback onEditProfile;

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
                        const CircleAvatar(
                          radius: 32,
                          child: Icon(
                            Icons.person_rounded,
                            size: 34,
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
                            _ProfileTemporaryStats
                                .daysTogetherLabel,
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
                const SizedBox(
                  height: PopqSpacing.md,
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onEditProfile,
                    child: const Text('내 프로필'),
                  ),
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
                    label: '방문 횟수',
                    value:
                    '${_ProfileTemporaryStats.visitCount}',
                  ),
                ),
                _StatDivider(isDark: isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons.paid_outlined,
                    label: '보유 포인트',
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