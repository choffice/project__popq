import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/discovery/customer_store_schedule.dart';

void main() {
  final DateTime holidayNoon = DateTime.utc(2026, 8, 15, 3);

  test('공휴일 데이터 사용 불가 시 PUBLIC_HOLIDAY 규칙을 적용하지 않는다', () {
    final schedule = _schedule(
      publicHolidayAvailable: false,
      publicHoliday: true,
      closureRules: const <Object?>[
        <String, Object?>{'ruleType': 'PUBLIC_HOLIDAY'},
      ],
    );

    expect(schedule.isOpenAt(now: holidayNoon), isTrue);
  });

  test('PUBLIC_HOLIDAY 설정 매장은 공식 공휴일에 닫고 안내문을 표시한다', () {
    final schedule = _schedule(
      publicHolidayAvailable: true,
      publicHoliday: true,
      closureRules: const <Object?>[
        <String, Object?>{'ruleType': 'PUBLIC_HOLIDAY'},
      ],
    );

    expect(schedule.isOpenAt(now: holidayNoon), isFalse);
    expect(schedule.todayLabel(now: holidayNoon), '오늘 공휴일 휴무');
  });

  test('PUBLIC_HOLIDAY 미설정 매장은 같은 공휴일에도 기존 시간대로 연다', () {
    final schedule = _schedule(
      publicHolidayAvailable: true,
      publicHoliday: true,
    );

    expect(schedule.isOpenAt(now: holidayNoon), isTrue);
    expect(schedule.todayLabel(now: holidayNoon), '오늘 24시간 영업');
  });

  test('공휴일이 아닌 날에는 PUBLIC_HOLIDAY 규칙이 있어도 기존 결과를 유지한다', () {
    final schedule = _schedule(
      publicHolidayAvailable: true,
      publicHoliday: false,
      closureRules: const <Object?>[
        <String, Object?>{'ruleType': 'PUBLIC_HOLIDAY'},
      ],
    );

    expect(schedule.isOpenAt(now: holidayNoon), isTrue);
  });

  test('임시휴무와 NTH_WEEKDAY 기존 판정을 유지한다', () {
    final exceptionSchedule = _schedule(
      publicHolidayAvailable: true,
      publicHoliday: true,
      closureRules: const <Object?>[
        <String, Object?>{'ruleType': 'PUBLIC_HOLIDAY'},
      ],
      scheduleExceptions: const <Object?>[
        <String, Object?>{
          'startDate': '2026-08-15',
          'endDate': '2026-08-15',
          'exceptionType': 'CLOSED',
          'memo': '시설 점검',
        },
      ],
    );
    final nthWeekdaySchedule = _schedule(
      publicHolidayAvailable: true,
      publicHoliday: false,
      closureRules: const <Object?>[
        <String, Object?>{
          'ruleType': 'NTH_WEEKDAY',
          'weekOfMonth': 3,
          'dayOfWeek': 'SATURDAY',
        },
      ],
    );

    expect(exceptionSchedule.isOpenAt(now: holidayNoon), isFalse);
    expect(exceptionSchedule.todayLabel(now: holidayNoon), '오늘 임시휴무 · 시설 점검');
    expect(nthWeekdaySchedule.isOpenAt(now: holidayNoon), isFalse);
    expect(nthWeekdaySchedule.todayLabel(now: holidayNoon), '오늘 정기휴무');
  });

  test('새 공휴일 필드가 없는 기존 응답도 정상 파싱한다', () {
    final schedule = CustomerStoreSchedule.fromJson(<String, Object?>{
      'businessHours': _businessHours,
      'closureRules': const <Object?>[
        <String, Object?>{'ruleType': 'PUBLIC_HOLIDAY'},
      ],
      'scheduleExceptions': const <Object?>[],
    });

    expect(schedule.publicHolidayAutoCalculationAvailable, isFalse);
    expect(schedule.publicHolidayEvaluationDate, isNull);
    expect(schedule.publicHoliday, isFalse);
    expect(schedule.isOpenAt(now: holidayNoon), isTrue);
  });
}

CustomerStoreSchedule _schedule({
  required bool publicHolidayAvailable,
  required bool publicHoliday,
  List<Object?> closureRules = const <Object?>[],
  List<Object?> scheduleExceptions = const <Object?>[],
}) {
  return CustomerStoreSchedule.fromJson(<String, Object?>{
    'businessHours': _businessHours,
    'closureRules': closureRules,
    'scheduleExceptions': scheduleExceptions,
    'publicHolidayAutoCalculationAvailable': publicHolidayAvailable,
    'publicHolidayEvaluationDate': '2026-08-15',
    'publicHoliday': publicHoliday,
  });
}

final List<Object?> _businessHours = <Object?>[
  for (final String day in const <String>[
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ])
    <String, Object?>{
      'dayOfWeek': day,
      'closed': false,
      'open24Hours': true,
      'openTime': null,
      'closeTime': null,
    },
];
