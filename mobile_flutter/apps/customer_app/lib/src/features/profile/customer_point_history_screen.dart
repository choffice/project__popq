import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';

class CustomerPointHistoryScreen extends StatefulWidget {
  const CustomerPointHistoryScreen({
    required this.repository,
    super.key,
  });

  final CustomerEngagementRepository repository;

  @override
  State<CustomerPointHistoryScreen> createState() =>
      _CustomerPointHistoryScreenState();
}

class _CustomerPointHistoryScreenState
    extends State<CustomerPointHistoryScreen> {
  late Future<CustomerPointSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.repository.getPointSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포인트 내역'),
      ),
      body: FutureBuilder<CustomerPointSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(
              message: '포인트 내역을 불러오고 있어요.',
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '포인트 내역을 불러오지 못했어요.',
              onRetry: _reload,
            );
          }

          final summary = snapshot.requireData;

          if (summary.histories.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      PopqSpacing.lg,
                      PopqSpacing.lg,
                      PopqSpacing.lg,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PointBalanceCard(
                            summary: summary,
                          ),
                          const SizedBox(
                            height: PopqSpacing.lg,
                          ),
                          Text(
                            '포인트 내역',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: PopqEmptyView(
                      icon: Icons.savings_outlined,
                      title: '아직 적립된 포인트가 없어요.',
                      description: 'POPQ에서 주문하면 적립된 포인트가 이곳에 표시됩니다.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(PopqSpacing.lg),
              children: [
                _PointBalanceCard(
                  summary: summary,
                ),
                const SizedBox(
                  height: PopqSpacing.lg,
                ),
                Text(
                  '포인트 내역',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(
                  height: PopqSpacing.sm,
                ),
                for (final history in summary.histories)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: PopqSpacing.sm,
                    ),
                    child: _PointHistoryCard(
                      history: history,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _reload() {
    setState(() {
      _summary = widget.repository.getPointSummary();
    });
  }
}

class _PointBalanceCard extends StatelessWidget {
  const _PointBalanceCard({
    required this.summary,
  });

  final CustomerPointSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '보유 포인트',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(
              height: PopqSpacing.xs,
            ),
            Text(
              '${_formatNumber(summary.balance)} P',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '결제 금액의 '
              '${summary.rewardRatePercent.toStringAsFixed(1)}%가 '
              '포인트로 적립돼요. 소수점은 제외됩니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PointHistoryCard extends StatelessWidget {
  const _PointHistoryCard({
    required this.history,
  });

  final CustomerPointHistory history;

  @override
  Widget build(BuildContext context) {
    final isReward = history.isReward;
    final isRaffle = history.type == 'RAFFLE_TICKET_PURCHASE';
    final pointColor = isReward
        ? const Color(0xFF16805B)
        : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: pointColor.withValues(
                alpha: 0.12,
              ),
              foregroundColor: pointColor,
              child: Icon(
                isReward
                    ? Icons.add_rounded
                    : Icons.remove_rounded,
              ),
            ),
            const SizedBox(
              width: PopqSpacing.md,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    isReward
                        ? '${_formatNumber(history.paymentAmount)}원 결제 적립'
                        : isRaffle
                            ? '월간 응모권 구매'
                            : '${_formatNumber(history.paymentAmount)}원 환불 회수',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _formatDateTime(
                      history.occurredAt,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: PopqSpacing.sm,
            ),
            Text(
              '${history.points > 0 ? '+' : ''}'
              '${_formatNumber(history.points)} P',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    color: pointColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(
      digits[index],
    );
  }

  return negative
      ? '-$buffer'
      : buffer.toString();
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}.$month.$day $hour:$minute';
}
