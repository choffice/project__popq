class CustomerStoreBusinessHour {
  const CustomerStoreBusinessHour({
    required this.dayOfWeek,
    required this.closed,
    required this.open24Hours,
    this.openTime,
    this.closeTime,
  });

  factory CustomerStoreBusinessHour.fromJson(Map<String, Object?> json) =>
      CustomerStoreBusinessHour(
        dayOfWeek: json['dayOfWeek'] as String,
        closed: json['closed'] as bool? ?? false,
        open24Hours: json['open24Hours'] as bool? ?? false,
        openTime: json['openTime'] as String?,
        closeTime: json['closeTime'] as String?,
      );

  final String dayOfWeek;
  final bool closed;
  final bool open24Hours;
  final String? openTime;
  final String? closeTime;

  String get signature => closed
      ? 'closed'
      : open24Hours
          ? '24'
          : '${_displayTime(openTime)}-${_displayTime(closeTime)}';
}

class CustomerStoreClosureRule {
  const CustomerStoreClosureRule({
    required this.ruleType,
    this.weekOfMonth,
    this.dayOfWeek,
  });

  factory CustomerStoreClosureRule.fromJson(Map<String, Object?> json) =>
      CustomerStoreClosureRule(
        ruleType: json['ruleType'] as String,
        weekOfMonth: (json['weekOfMonth'] as num?)?.toInt(),
        dayOfWeek: json['dayOfWeek'] as String?,
      );

  final String ruleType;
  final int? weekOfMonth;
  final String? dayOfWeek;
}

class CustomerStoreScheduleException {
  const CustomerStoreScheduleException({
    required this.startDate,
    required this.endDate,
    this.memo,
  });

  factory CustomerStoreScheduleException.fromJson(Map<String, Object?> json) =>
      CustomerStoreScheduleException(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        memo: json['memo'] as String?,
      );

  final DateTime startDate;
  final DateTime endDate;
  final String? memo;
}

class CustomerStoreSchedule {
  CustomerStoreSchedule({
    required List<CustomerStoreBusinessHour> businessHours,
    List<CustomerStoreClosureRule> closureRules = const [],
    List<CustomerStoreScheduleException> scheduleExceptions = const [],
    this.publicHolidayAutoCalculationAvailable = false,
  }) : businessHours = List.unmodifiable(businessHours),
       closureRules = List.unmodifiable(closureRules),
       scheduleExceptions = List.unmodifiable(scheduleExceptions);

  factory CustomerStoreSchedule.fromJson(
    Object? value, {
    String? legacyOpenTime,
    String? legacyCloseTime,
    List<String> legacyClosedDays = const [],
  }) {
    if (value is Map) {
      final json = Map<String, Object?>.from(value);
      final hours = (json['businessHours'] as List<Object?>? ?? const [])
          .map((item) => CustomerStoreBusinessHour.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(growable: false);
      final hoursByDay = {
        for (final hour in hours) hour.dayOfWeek: hour,
      };
      if (hoursByDay.length == 7 &&
          _weekdays.every(hoursByDay.containsKey)) {
        return CustomerStoreSchedule(
          businessHours: _weekdays
              .map((day) => hoursByDay[day]!)
              .toList(growable: false),
          closureRules: (json['closureRules'] as List<Object?>? ?? const [])
              .map((item) => CustomerStoreClosureRule.fromJson(
                    Map<String, Object?>.from(item as Map),
                  ))
              .toList(growable: false),
          scheduleExceptions:
              (json['scheduleExceptions'] as List<Object?>? ?? const [])
                  .map((item) => CustomerStoreScheduleException.fromJson(
                        Map<String, Object?>.from(item as Map),
                      ))
                  .toList(growable: false),
          publicHolidayAutoCalculationAvailable:
              json['publicHolidayAutoCalculationAvailable'] as bool? ?? false,
        );
      }
    }
    return CustomerStoreSchedule.legacy(
      openTime: legacyOpenTime,
      closeTime: legacyCloseTime,
      closedDays: legacyClosedDays,
    );
  }

  factory CustomerStoreSchedule.legacy({
    String? openTime,
    String? closeTime,
    List<String> closedDays = const [],
  }) => CustomerStoreSchedule(
    businessHours: _weekdays
        .map((day) => CustomerStoreBusinessHour(
              dayOfWeek: day,
              closed: closedDays.contains(day),
              open24Hours: openTime != null && openTime == closeTime,
              openTime: openTime,
              closeTime: closeTime,
            ))
        .toList(growable: false),
  );

  final List<CustomerStoreBusinessHour> businessHours;
  final List<CustomerStoreClosureRule> closureRules;
  final List<CustomerStoreScheduleException> scheduleExceptions;
  final bool publicHolidayAutoCalculationAvailable;

  String todayLabel({DateTime? now}) {
    final koreaNow = now ??
        DateTime.now().toUtc().add(const Duration(hours: 9));
    final date = _dateOnly(koreaNow);
    final exception = scheduleExceptions.where((value) =>
        !date.isBefore(_dateOnly(value.startDate)) &&
        !date.isAfter(_dateOnly(value.endDate))).firstOrNull;
    if (exception != null) {
      final memo = exception.memo?.trim() ?? '';
      return memo.isEmpty ? '오늘 임시휴무' : '오늘 임시휴무 · $memo';
    }

    final day = _weekdayFor(date.weekday);
    final week = ((date.day - 1) ~/ 7) + 1;
    final regularClosure = closureRules.any((value) =>
        value.ruleType == 'NTH_WEEKDAY' &&
        value.dayOfWeek == day &&
        value.weekOfMonth == week);
    if (regularClosure) return '오늘 정기휴무';

    final hour = businessHours.where((value) => value.dayOfWeek == day).firstOrNull;
    if (hour == null) return '오늘 영업시간 정보 없음';
    if (hour.closed) return '오늘 휴무';
    if (hour.open24Hours) return '오늘 24시간 영업';
    if (hour.openTime == null || hour.closeTime == null) {
      return '오늘 영업시간 정보 없음';
    }
    return '오늘 ${_hourLabel(hour)}';
  }

  List<String> summaryLines() {
    final groups = <String, List<CustomerStoreBusinessHour>>{};
    for (final hour in businessHours) {
      groups.putIfAbsent(hour.signature, () => []).add(hour);
    }
    final lines = <String>[];
    for (final values in groups.values) {
      final days = values.map((value) => value.dayOfWeek).toList();
      final label = days.length == 7
          ? '매일'
          : _sameDays(days, _weekdays.take(5).toList())
              ? '평일'
              : _sameDays(days, _weekdays.skip(5).toList())
                  ? '주말'
                  : days.map((day) => _dayLabels[day]).join('·');
      final hour = values.first;
      lines.add(hour.closed
          ? '$label 휴무'
          : hour.open24Hours
              ? '$label 24시간 영업'
              : hour.openTime == null || hour.closeTime == null
                  ? '$label 영업시간 정보 없음'
                  : '$label ${_hourLabel(hour)}');
    }
    for (final rule in closureRules) {
      if (rule.ruleType == 'PUBLIC_HOLIDAY') {
        lines.add('공휴일 휴무');
      } else {
        lines.add(
          '정기휴무 매월 ${_ordinal(rule.weekOfMonth ?? 1)} '
          '${_dayLabels[rule.dayOfWeek]}요일',
        );
      }
    }
    for (final value in scheduleExceptions) {
      final range = _sameDate(value.startDate, value.endDate)
          ? _dateText(value.startDate)
          : '${_dateText(value.startDate)} ~ ${_dateText(value.endDate)}';
      final memo = value.memo?.trim() ?? '';
      lines.add('임시휴무 $range${memo.isEmpty ? '' : ' · $memo'}');
    }
    return lines;
  }
}

const _weekdays = <String>[
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
  'FRIDAY', 'SATURDAY', 'SUNDAY',
];
const _dayLabels = <String, String>{
  'MONDAY': '월', 'TUESDAY': '화', 'WEDNESDAY': '수',
  'THURSDAY': '목', 'FRIDAY': '금', 'SATURDAY': '토', 'SUNDAY': '일',
};

String _weekdayFor(int weekday) => _weekdays[weekday - 1];
String _hourLabel(CustomerStoreBusinessHour value) {
  final open = _displayTime(value.openTime) ?? '--:--';
  final close = _displayTime(value.closeTime) ?? '--:--';
  final overnight = _minutes(value.closeTime) < _minutes(value.openTime);
  return '$open ~ ${overnight ? '익일 ' : ''}$close';
}
String? _displayTime(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parts = value.split(':');
  return parts.length < 2 ? value : '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}
int _minutes(String? value) {
  final parts = value?.split(':') ?? const [];
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}
bool _sameDays(List<String> left, List<String> right) =>
    left.length == right.length && left.toSet().containsAll(right);
bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;
DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
String _ordinal(int value) =>
    const <String>['첫째', '둘째', '셋째', '넷째', '다섯째'][
      (value < 1 ? 1 : value > 5 ? 5 : value) - 1
    ];

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
