import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

const sellerWeekdays = <String>[
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
  'FRIDAY', 'SATURDAY', 'SUNDAY',
];

const _dayLabels = <String, String>{
  'MONDAY': '월', 'TUESDAY': '화', 'WEDNESDAY': '수',
  'THURSDAY': '목', 'FRIDAY': '금', 'SATURDAY': '토', 'SUNDAY': '일',
};

enum SellerScheduleEditMode { allDays, weekdayWeekend, daily }

class SellerBusinessHour {
  const SellerBusinessHour({
    required this.dayOfWeek,
    required this.closed,
    required this.open24Hours,
    this.openTime,
    this.closeTime,
  });

  factory SellerBusinessHour.fromJson(Map<String, Object?> json) {
    return SellerBusinessHour(
      dayOfWeek: json['dayOfWeek'] as String,
      closed: json['closed'] as bool? ?? false,
      open24Hours: json['open24Hours'] as bool? ?? false,
      openTime: _parseTime(json['openTime'] as String?),
      closeTime: _parseTime(json['closeTime'] as String?),
    );
  }

  final String dayOfWeek;
  final bool closed;
  final bool open24Hours;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  SellerBusinessHour copyWith({
    String? dayOfWeek,
    bool? closed,
    bool? open24Hours,
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
  }) => SellerBusinessHour(
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    closed: closed ?? this.closed,
    open24Hours: open24Hours ?? this.open24Hours,
    openTime: openTime ?? this.openTime,
    closeTime: closeTime ?? this.closeTime,
  );

  Map<String, Object?> toJson() => {
    'dayOfWeek': dayOfWeek,
    'closed': closed,
    'open24Hours': open24Hours,
    'openTime': closed || open24Hours ? null : _apiTime(openTime),
    'closeTime': closed || open24Hours ? null : _apiTime(closeTime),
  };

  String get signature => closed
      ? 'closed'
      : open24Hours
          ? '24'
          : '${_apiTime(openTime)}-${_apiTime(closeTime)}';
}

class SellerClosureRule {
  const SellerClosureRule({
    required this.ruleType,
    this.weekOfMonth,
    this.dayOfWeek,
  });

  factory SellerClosureRule.fromJson(Map<String, Object?> json) =>
      SellerClosureRule(
        ruleType: json['ruleType'] as String,
        weekOfMonth: (json['weekOfMonth'] as num?)?.toInt(),
        dayOfWeek: json['dayOfWeek'] as String?,
      );

  final String ruleType;
  final int? weekOfMonth;
  final String? dayOfWeek;

  Map<String, Object?> toJson() => {
    'ruleType': ruleType,
    'weekOfMonth': weekOfMonth,
    'dayOfWeek': dayOfWeek,
  };
}

class SellerScheduleException {
  const SellerScheduleException({
    required this.startDate,
    required this.endDate,
    this.memo,
  });

  factory SellerScheduleException.fromJson(Map<String, Object?> json) =>
      SellerScheduleException(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        memo: json['memo'] as String?,
      );

  final DateTime startDate;
  final DateTime endDate;
  final String? memo;

  Map<String, Object?> toJson() => {
    'startDate': _date(startDate),
    'endDate': _date(endDate),
    'exceptionType': 'CLOSED',
    'memo': memo,
  };
}

class SellerBusinessSchedule {
  SellerBusinessSchedule({
    required List<SellerBusinessHour> businessHours,
    List<SellerClosureRule> closureRules = const [],
    List<SellerScheduleException> scheduleExceptions = const [],
    this.publicHolidayAutoCalculationAvailable = false,
  }) : businessHours = List.unmodifiable(businessHours),
       closureRules = List.unmodifiable(closureRules),
       scheduleExceptions = List.unmodifiable(scheduleExceptions);

  factory SellerBusinessSchedule.fromJson(
    Object? value, {
    String? legacyOpenTime,
    String? legacyCloseTime,
    List<String> legacyClosedDays = const [],
  }) {
    if (value is Map) {
      final json = Map<String, Object?>.from(value);
      final hours = (json['businessHours'] as List<Object?>? ?? const [])
          .map((item) => SellerBusinessHour.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList();
      final hoursByDay = {
        for (final hour in hours) hour.dayOfWeek: hour,
      };
      if (hoursByDay.length == 7 &&
          sellerWeekdays.every(hoursByDay.containsKey)) {
        return SellerBusinessSchedule(
          businessHours: sellerWeekdays
              .map((day) => hoursByDay[day]!)
              .toList(growable: false),
          closureRules: (json['closureRules'] as List<Object?>? ?? const [])
              .map((item) => SellerClosureRule.fromJson(
                    Map<String, Object?>.from(item as Map),
                  ))
              .toList(),
          scheduleExceptions:
              (json['scheduleExceptions'] as List<Object?>? ?? const [])
                  .map((item) => SellerScheduleException.fromJson(
                        Map<String, Object?>.from(item as Map),
                      ))
                  .toList(),
          publicHolidayAutoCalculationAvailable:
              json['publicHolidayAutoCalculationAvailable'] as bool? ?? false,
        );
      }
    }
    return SellerBusinessSchedule.legacy(
      openTime: legacyOpenTime,
      closeTime: legacyCloseTime,
      closedDays: legacyClosedDays,
    );
  }

  factory SellerBusinessSchedule.legacy({
    String? openTime,
    String? closeTime,
    List<String> closedDays = const [],
  }) {
    final open = _parseTime(openTime);
    final close = _parseTime(closeTime);
    return SellerBusinessSchedule(
      businessHours: sellerWeekdays
          .map((day) => SellerBusinessHour(
                dayOfWeek: day,
                closed: closedDays.contains(day),
                open24Hours: open != null &&
                    close != null &&
                    _minutes(open) == _minutes(close),
                openTime: open,
                closeTime: close,
              ))
          .toList(),
    );
  }

  factory SellerBusinessSchedule.standard() {
    return SellerBusinessSchedule.legacy(
      openTime: '10:00',
      closeTime: '22:00',
    );
  }

  final List<SellerBusinessHour> businessHours;
  final List<SellerClosureRule> closureRules;
  final List<SellerScheduleException> scheduleExceptions;
  final bool publicHolidayAutoCalculationAvailable;

  SellerScheduleEditMode get detectedMode {
    final signatures = businessHours.map((value) => value.signature).toList();
    if (signatures.toSet().length == 1) return SellerScheduleEditMode.allDays;
    if (signatures.take(5).toSet().length == 1 &&
        signatures.skip(5).toSet().length == 1) {
      return SellerScheduleEditMode.weekdayWeekend;
    }
    return SellerScheduleEditMode.daily;
  }

  Map<String, Object?> toJson() => {
    'businessHours': businessHours.map((value) => value.toJson()).toList(),
    'closureRules': closureRules.map((value) => value.toJson()).toList(),
    'scheduleExceptions':
        scheduleExceptions.map((value) => value.toJson()).toList(),
  };

  List<String> get legacyClosedDays => businessHours
      .where((value) => value.closed)
      .map((value) => value.dayOfWeek)
      .toList();

  SellerBusinessHour get legacyRepresentative => businessHours.firstWhere(
    (value) => !value.closed && !value.open24Hours,
    orElse: () => businessHours.first,
  );

  String get legacyOpenTimeForApi {
    final value = legacyRepresentative;
    if (value.open24Hours) return '00:00:00';
    return _apiTime(value.openTime ?? const TimeOfDay(hour: 0, minute: 0))!;
  }

  String get legacyCloseTimeForApi {
    final value = legacyRepresentative;
    if (value.open24Hours) return '00:00:00';
    return _apiTime(value.closeTime ?? const TimeOfDay(hour: 0, minute: 0))!;
  }

  String? get validationMessage {
    for (final value in businessHours) {
      if (value.closed || value.open24Hours) continue;
      if (value.openTime == null || value.closeTime == null) {
        return '${_dayLabels[value.dayOfWeek]}요일의 시작·종료 시간을 선택해 주세요.';
      }
      if (_minutes(value.openTime!) == _minutes(value.closeTime!)) {
        return '${_dayLabels[value.dayOfWeek]}요일의 시작·종료 시간이 같습니다. '
            '24시간 영업은 별도 항목을 선택해 주세요.';
      }
    }
    return null;
  }
}

class SellerBusinessScheduleEditor extends StatefulWidget {
  const SellerBusinessScheduleEditor({
    required this.initialSchedule,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final SellerBusinessSchedule initialSchedule;
  final ValueChanged<SellerBusinessSchedule> onChanged;
  final bool enabled;

  @override
  State<SellerBusinessScheduleEditor> createState() =>
      _SellerBusinessScheduleEditorState();
}

class _SellerBusinessScheduleEditorState
    extends State<SellerBusinessScheduleEditor> {
  late SellerScheduleEditMode _mode;
  late Map<String, SellerBusinessHour> _hours;
  late List<SellerClosureRule> _rules;
  late List<SellerScheduleException> _exceptions;
  late bool _publicHolidayAutoCalculationAvailable;
  SellerBusinessSchedule? _lastEmittedSchedule;

  @override
  void initState() {
    super.initState();
    _reset(widget.initialSchedule);
  }

  @override
  void didUpdateWidget(covariant SellerBusinessScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.initialSchedule, _lastEmittedSchedule) &&
        !identical(oldWidget.initialSchedule, widget.initialSchedule)) {
      _reset(widget.initialSchedule);
    }
  }

  void _reset(SellerBusinessSchedule value) {
    _mode = value.detectedMode;
    _hours = {for (final hour in value.businessHours) hour.dayOfWeek: hour};
    _rules = List.of(value.closureRules);
    _exceptions = List.of(value.scheduleExceptions);
    _publicHolidayAutoCalculationAvailable =
        value.publicHolidayAutoCalculationAvailable;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<SellerScheduleEditMode>(
          segments: const [
            ButtonSegment(value: SellerScheduleEditMode.allDays, label: Text('모든 요일')),
            ButtonSegment(value: SellerScheduleEditMode.weekdayWeekend, label: Text('평일/주말')),
            ButtonSegment(value: SellerScheduleEditMode.daily, label: Text('요일별')),
          ],
          selected: {_mode},
          onSelectionChanged: widget.enabled
              ? (values) => _changeMode(values.single)
              : null,
        ),
        const SizedBox(height: PopqSpacing.md),
        for (final group in _groupsForMode(_mode))
          _scheduleRow(group.$1, group.$2),
        const Divider(height: PopqSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text('휴무 및 예외 일정',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: '정기 휴무 추가',
              onPressed: widget.enabled ? _addNthRule : null,
              icon: const Icon(Icons.event_repeat_rounded),
            ),
            IconButton(
              tooltip: '임시 휴무 추가',
              onPressed: widget.enabled ? _addException : null,
              icon: const Icon(Icons.event_busy_rounded),
            ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('공휴일 휴무'),
          subtitle: Text(
            _publicHolidayAutoCalculationAvailable
                ? '대한민국 공휴일에는 자동으로 휴무 처리됩니다.'
                : '정책은 저장되지만 현재 자동 공휴일 판정 데이터는 없습니다.',
          ),
          value: _rules.any((value) => value.ruleType == 'PUBLIC_HOLIDAY'),
          onChanged: widget.enabled ? _togglePublicHoliday : null,
        ),
        for (final rule in _rules.where((value) => value.ruleType == 'NTH_WEEKDAY'))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_closureRuleLabel(rule)),
            trailing: IconButton(
              tooltip: '정기 휴무 삭제',
              onPressed: widget.enabled ? () => _removeRule(rule) : null,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        for (final exception in _exceptions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_exceptionLabel(exception)),
            subtitle: exception.memo?.trim().isNotEmpty == true
                ? Text(exception.memo!)
                : null,
            trailing: IconButton(
              tooltip: '임시 휴무 삭제',
              onPressed: widget.enabled ? () => _removeException(exception) : null,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
  }

  Widget _scheduleRow(String label, List<String> days) {
    final value = _hours[days.first]!;
    return Card(
      margin: const EdgeInsets.only(bottom: PopqSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 70, child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('휴무'),
                    value: value.closed,
                    onChanged: widget.enabled
                        ? (closed) => _apply(days, value.copyWith(
                              closed: closed,
                              open24Hours: closed ? false : value.open24Hours,
                              openTime: closed
                                  ? value.openTime
                                  : value.openTime ??
                                      const TimeOfDay(hour: 10, minute: 0),
                              closeTime: closed
                                  ? value.closeTime
                                  : value.closeTime ??
                                      const TimeOfDay(hour: 22, minute: 0),
                            ))
                        : null,
                  ),
                ),
              ],
            ),
            if (!value.closed) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('24시간 영업'),
                value: value.open24Hours,
                onChanged: widget.enabled
                    ? (checked) => _apply(days, value.copyWith(
                          open24Hours: checked ?? false,
                          openTime: checked == false
                              ? value.openTime ??
                                  const TimeOfDay(hour: 10, minute: 0)
                              : value.openTime,
                          closeTime: checked == false
                              ? value.closeTime ??
                                  const TimeOfDay(hour: 22, minute: 0)
                              : value.closeTime,
                        ))
                    : null,
              ),
              if (!value.open24Hours)
                Row(
                  children: [
                    Expanded(child: _timeButton('시작', value.openTime,
                        (time) => _apply(days, value.copyWith(openTime: time)))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: PopqSpacing.xs),
                      child: Text('~'),
                    ),
                    Expanded(child: _timeButton('종료', value.closeTime,
                        (time) => _apply(days, value.copyWith(closeTime: time)))),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeButton(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay> onSelected,
  ) => OutlinedButton(
    onPressed: widget.enabled
        ? () async {
            final selected = await showSellerWheelTimePicker(
              context,
              title: '$label 시간',
              initialTime: value ?? const TimeOfDay(hour: 10, minute: 0),
            );
            if (selected != null) onSelected(selected);
          }
        : null,
    child: Text('$label ${_displayTime(value)}'),
  );

  void _changeMode(SellerScheduleEditMode mode) {
    final template = _hours['MONDAY']!;
    if (mode == SellerScheduleEditMode.allDays) {
      _apply(sellerWeekdays, template, notify: false);
    } else if (mode == SellerScheduleEditMode.weekdayWeekend) {
      _apply(sellerWeekdays.take(5).toList(), template, notify: false);
      final weekend = _hours['SATURDAY']!;
      _apply(sellerWeekdays.skip(5).toList(), weekend, notify: false);
    }
    setState(() => _mode = mode);
    _notify();
  }

  void _apply(
    List<String> days,
    SellerBusinessHour template, {
    bool notify = true,
  }) {
    setState(() {
      for (final day in days) {
        _hours[day] = template.copyWith(dayOfWeek: day);
      }
    });
    if (notify) _notify();
  }

  Future<void> _addNthRule() async {
    var week = 2;
    var day = 'WEDNESDAY';
    final result = await showDialog<SellerClosureRule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('월간 정기휴무 추가'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: week,
                  items: List.generate(5, (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1}번째'),
                  )),
                  onChanged: (value) => setDialogState(() => week = value ?? 1),
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: day,
                  items: sellerWeekdays.map((value) => DropdownMenuItem(
                    value: value,
                    child: Text('${_dayLabels[value]}요일'),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => day = value ?? day),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(
              dialogContext,
              SellerClosureRule(
                ruleType: 'NTH_WEEKDAY', weekOfMonth: week, dayOfWeek: day,
              ),
            ), child: const Text('추가')),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _rules.add(result));
      _notify();
    }
  }

  Future<void> _addException() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (range == null || !mounted) return;
    final memo = await showDialog<String>(
      context: context,
      builder: (_) => const _ScheduleMemoDialog(),
    );
    if (memo != null && mounted) {
      setState(() => _exceptions.add(SellerScheduleException(
        startDate: range.start, endDate: range.end,
        memo: memo.isEmpty ? null : memo,
      )));
      _notify();
    }
  }

  void _togglePublicHoliday(bool? checked) {
    setState(() {
      _rules.removeWhere((value) => value.ruleType == 'PUBLIC_HOLIDAY');
      if (checked == true) {
        _rules.add(const SellerClosureRule(ruleType: 'PUBLIC_HOLIDAY'));
      }
    });
    _notify();
  }

  void _removeRule(SellerClosureRule value) {
    setState(() => _rules.remove(value));
    _notify();
  }

  void _removeException(SellerScheduleException value) {
    setState(() => _exceptions.remove(value));
    _notify();
  }

  void _notify() {
    final value = SellerBusinessSchedule(
      businessHours: sellerWeekdays.map((day) => _hours[day]!).toList(),
      closureRules: _rules,
      scheduleExceptions: _exceptions,
      publicHolidayAutoCalculationAvailable:
          _publicHolidayAutoCalculationAvailable,
    );
    _lastEmittedSchedule = value;
    widget.onChanged(value);
  }
}

class _ScheduleMemoDialog extends StatefulWidget {
  const _ScheduleMemoDialog();

  @override
  State<_ScheduleMemoDialog> createState() => _ScheduleMemoDialogState();
}

class _ScheduleMemoDialogState extends State<_ScheduleMemoDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('휴무 메모'),
    content: TextField(
      controller: _controller,
      maxLength: 255,
      decoration: const InputDecoration(hintText: '예: 여름휴가, 시설 점검'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('추가'),
      ),
    ],
  );
}

Future<TimeOfDay?> showSellerWheelTimePicker(
  BuildContext context, {
  required String title,
  required TimeOfDay initialTime,
}) {
  var period = initialTime.hour >= 12 ? 1 : 0;
  var hour = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
  var minute = initialTime.minute;
  final periodController = FixedExtentScrollController(initialItem: period);
  final hourController = FixedExtentScrollController(initialItem: hour - 1);
  final minuteController = FixedExtentScrollController(initialItem: minute);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: PopqSpacing.md),
            SizedBox(
              height: 210,
              child: Row(
                children: [
                  Expanded(child: CupertinoPicker(
                    itemExtent: 42,
                    scrollController: periodController,
                    onSelectedItemChanged: (value) => period = value,
                    children: const [Center(child: Text('오전')), Center(child: Text('오후'))],
                  )),
                  Expanded(child: CupertinoPicker(
                    itemExtent: 42,
                    scrollController: hourController,
                    onSelectedItemChanged: (value) => hour = value + 1,
                    children: List.generate(12, (index) =>
                        Center(child: Text('${index + 1}'.padLeft(2, '0')))),
                  )),
                  const Text(':'),
                  Expanded(child: CupertinoPicker(
                    itemExtent: 42,
                    scrollController: minuteController,
                    onSelectedItemChanged: (value) => minute = value,
                    children: List.generate(60, (index) =>
                        Center(child: Text('$index'.padLeft(2, '0')))),
                  )),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('취소'),
                )),
                Expanded(child: FilledButton(
                  onPressed: () {
                    final hour24 = period == 0 ? hour % 12 : (hour % 12) + 12;
                    Navigator.pop(sheetContext, TimeOfDay(hour: hour24, minute: minute));
                  },
                  child: const Text('확인'),
                )),
              ],
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() {
    periodController.dispose();
    hourController.dispose();
    minuteController.dispose();
  });
}

List<String> sellerScheduleSummary(SellerBusinessSchedule schedule) {
  final groups = <String, List<SellerBusinessHour>>{};
  for (final hour in schedule.businessHours) {
    groups.putIfAbsent(hour.signature, () => []).add(hour);
  }
  final lines = <String>[];
  for (final values in groups.values) {
    final days = values.map((value) => value.dayOfWeek).toList();
    final label = days.length == 7
        ? '매일'
        : _sameDays(days, sellerWeekdays.take(5).toList())
            ? '평일'
            : _sameDays(days, sellerWeekdays.skip(5).toList())
                ? '주말'
                : days.map((day) => _dayLabels[day]).join('·');
    final value = values.first;
    lines.add(value.closed
        ? '$label 휴무'
        : value.open24Hours
            ? '$label 24시간 영업'
            : value.openTime == null || value.closeTime == null
                ? '$label 영업시간 정보 없음'
                : '$label ${_displayTime(value.openTime)} ~ '
                    '${_isNextDay(value) ? '익일 ' : ''}${_displayTime(value.closeTime)}');
  }
  for (final rule in schedule.closureRules) {
    lines.add(rule.ruleType == 'PUBLIC_HOLIDAY'
        ? '공휴일 휴무'
        : '정기휴무 ${_closureRuleLabel(rule)}');
  }
  for (final value in schedule.scheduleExceptions) {
    lines.add('임시휴무 ${_exceptionLabel(value)}'
        '${value.memo?.trim().isNotEmpty == true ? ' ${value.memo}' : ''}');
  }
  return lines;
}

List<(String, List<String>)> _groupsForMode(SellerScheduleEditMode mode) =>
    switch (mode) {
      SellerScheduleEditMode.allDays => [('매일', sellerWeekdays)],
      SellerScheduleEditMode.weekdayWeekend => [
        ('평일', sellerWeekdays.take(5).toList()),
        ('주말', sellerWeekdays.skip(5).toList()),
      ],
      SellerScheduleEditMode.daily => sellerWeekdays
          .map((day) => ('${_dayLabels[day]}요일', [day]))
          .toList(),
    };

bool _sameDays(List<String> left, List<String> right) =>
    left.length == right.length && left.toSet().containsAll(right);

bool _isNextDay(SellerBusinessHour value) =>
    value.openTime != null && value.closeTime != null &&
    _minutes(value.closeTime!) < _minutes(value.openTime!);

String _closureRuleLabel(SellerClosureRule value) =>
    '매월 ${_ordinal(value.weekOfMonth ?? 1)} ${_dayLabels[value.dayOfWeek]}요일';

String _exceptionLabel(SellerScheduleException value) =>
    _date(value.startDate) == _date(value.endDate)
        ? _date(value.startDate)
        : '${_date(value.startDate)} ~ ${_date(value.endDate)}';

String _ordinal(int value) => const ['첫째', '둘째', '셋째', '넷째', '다섯째'][value - 1];

TimeOfDay? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String? _apiTime(TimeOfDay? value) => value == null
    ? null
    : '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:00';

String _displayTime(TimeOfDay? value) => value == null
    ? '--:--'
    : '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;
String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
