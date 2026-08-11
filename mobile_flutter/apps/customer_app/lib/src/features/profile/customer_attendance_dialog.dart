import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';

Future<void> showCustomerAttendanceDialog({
  required BuildContext context,
  required CustomerEngagementRepository repository,
  required ValueChanged<CustomerActivitySummary> onSummaryChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CustomerAttendanceDialog(
      repository: repository,
      onSummaryChanged: onSummaryChanged,
    ),
  );
}

class _CustomerAttendanceDialog extends StatefulWidget {
  const _CustomerAttendanceDialog({
    required this.repository,
    required this.onSummaryChanged,
  });

  final CustomerEngagementRepository repository;
  final ValueChanged<CustomerActivitySummary> onSummaryChanged;

  @override
  State<_CustomerAttendanceDialog> createState() =>
      _CustomerAttendanceDialogState();
}

class _CustomerAttendanceDialogState extends State<_CustomerAttendanceDialog> {
  CustomerAttendance? _attendance;
  Object? _loadError;
  bool _loading = true;
  bool _checking = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final attendance = await widget.repository.getAttendance();
      if (!mounted) return;
      setState(() {
        _attendance = attendance;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _checkAttendance() async {
    if (_checking || _attendance?.checkedToday == true) return;

    setState(() {
      _checking = true;
      _resultMessage = null;
    });

    try {
      final attendance = await widget.repository.checkAttendance();
      if (!mounted) return;
      widget.onSummaryChanged(attendance.activitySummary);
      setState(() {
        _attendance = attendance;
        _checking = false;
        _resultMessage = attendance.newlyChecked
            ? '오늘 출석 완료! 체크포인트가 1회 올랐어요.'
            : '오늘 출석은 이미 완료했어요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _resultMessage = '출석을 기록하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? PopqPalette.lime : PopqPalette.forest;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: PopqSpacing.md,
        vertical: PopqSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '오늘도 POPQ 출석',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _checking
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '하루 한 번 출석하고 체크포인트를 1회 채워보세요.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: PopqSpacing.lg),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: PopqSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null)
                  _AttendanceLoadError(onRetry: _load)
                else ...[
                  _AttendanceCalendar(attendance: _attendance!),
                  const SizedBox(height: PopqSpacing.md),
                  _CheckpointSummary(
                    summary: _attendance!.activitySummary,
                    accent: accent,
                  ),
                  if (_resultMessage != null) ...[
                    const SizedBox(height: PopqSpacing.sm),
                    Text(
                      _resultMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _attendance!.checkedToday ? accent : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: PopqSpacing.md),
                  FilledButton.icon(
                    onPressed: _attendance!.checkedToday || _checking
                        ? null
                        : _checkAttendance,
                    icon: _checking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _attendance!.checkedToday
                                ? Icons.check_circle_rounded
                                : Icons.event_available_rounded,
                          ),
                    label: Text(
                      _attendance!.checkedToday ? '오늘 출석 완료' : '오늘 출석하기',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar({required this.attendance});

  final CustomerAttendance attendance;

  static const _weekdays = <String>['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? PopqPalette.lime : PopqPalette.forest;
    final today = attendance.today;
    final firstDay = DateTime(today.year, today.month);
    final leadingDays = firstDay.weekday % DateTime.daysPerWeek;
    final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final checkedDateKeys = attendance.checkedDates.map(_dateKey).toSet();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          children: [
            Text(
              '${today.year}년 ${today.month}월',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: PopqSpacing.sm),
            Row(
              children: _weekdays
                  .map(
                    (weekday) => Expanded(
                      child: Text(
                        weekday,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: PopqSpacing.xs),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 42,
              ),
              itemCount: cellCount,
              itemBuilder: (context, index) {
                final day = index - leadingDays + 1;
                if (day < 1 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(today.year, today.month, day);
                final isToday = _dateKey(date) == _dateKey(today);
                final checked = checkedDateKeys.contains(_dateKey(date));

                return Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked ? accent : Colors.transparent,
                      border: isToday && !checked
                          ? Border.all(color: accent, width: 2)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: checked
                                ? (isDark ? PopqPalette.night : Colors.white)
                                : null,
                            fontWeight: isToday || checked
                                ? FontWeight.w900
                                : FontWeight.w500,
                          ),
                        ),
                        if (checked)
                          const Positioned(
                            right: 1,
                            bottom: 1,
                            child: Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static int _dateKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
}

class _CheckpointSummary extends StatelessWidget {
  const _CheckpointSummary({required this.summary, required this.accent});

  final CustomerActivitySummary summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextLabel = summary.nextCheckpoint == null
        ? '모든 체크포인트 달성'
        : '다음 체크포인트까지 ${summary.remainingCount}회';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PopqSpacing.md,
        vertical: PopqSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: accent),
          const SizedBox(width: PopqSpacing.sm),
          Expanded(
            child: Text(
              nextLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '누적 ${summary.totalCount}회',
            style: theme.textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceLoadError extends StatelessWidget {
  const _AttendanceLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PopqSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40),
          const SizedBox(height: PopqSpacing.sm),
          const Text('출석 달력을 불러오지 못했어요.', textAlign: TextAlign.center),
          const SizedBox(height: PopqSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
