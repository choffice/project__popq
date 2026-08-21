import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/discovery/customer_store_schedule.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_controller.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_screen.dart';
import 'package:popq_customer_app/src/features/permissions/customer_permission_gateway.dart';

void main() {
  test('Memory repository는 가게명과 행사명으로 추천 결과를 검색한다', () async {
    final MemoryStoreDiscoveryRepository repository =
        MemoryStoreDiscoveryRepository();

    final List<CustomerStore> storeNameResults = await repository.search(
      query: '주말 디저트 마켓',
    );
    final List<CustomerStore> eventNameResults = await repository.search(
      query: '성수 디저트 페스타',
    );

    expect(storeNameResults.map((store) => store.storeId), contains(2));
    expect(eventNameResults.map((store) => store.storeId), contains(2));
  });

  testWidgets('추천 검색은 입력 후 300ms가 지난 뒤 한 번만 요청한다', (tester) async {
    final _SearchRepository repository = _SearchRepository(
      onSearch: (_) async => const <CustomerStore>[],
    );
    final StoreSearchSuggestionController controller =
        StoreSearchSuggestionController(repository: repository);
    addTearDown(controller.dispose);

    controller.schedule(query: '아메리카노', location: _location, radiusKm: 10);

    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.queries, <String?>['아메리카노']);
  });

  testWidgets('서버가 메뉴명으로 반환한 Store를 로컬 문자열 비교 없이 유지한다', (tester) async {
    final CustomerStore serverResult = _store(
      id: 10,
      name: '모모 로스터스',
      type: 'LOCAL_STORE',
    );
    final _SearchRepository repository = _SearchRepository(
      onSearch: (_) async => <CustomerStore>[serverResult],
    );
    final StoreSearchSuggestionController controller =
        StoreSearchSuggestionController(
          repository: repository,
          debounceDuration: Duration.zero,
        );
    addTearDown(controller.dispose);

    controller.schedule(query: '바닐라 아메리카노', location: _location, radiusKm: 10);
    await tester.pump();
    await tester.pump();

    expect(controller.results, <CustomerStore>[serverResult]);
  });

  testWidgets('빠른 연속 입력에서는 늦게 끝난 이전 응답을 무시한다', (tester) async {
    final Map<String, Completer<List<CustomerStore>>> pending =
        <String, Completer<List<CustomerStore>>>{};
    final _SearchRepository repository = _SearchRepository(
      onSearch: (query) {
        return (pending[query!] = Completer<List<CustomerStore>>()).future;
      },
    );
    final StoreSearchSuggestionController controller =
        StoreSearchSuggestionController(
          repository: repository,
          debounceDuration: Duration.zero,
        );
    addTearDown(controller.dispose);

    controller.schedule(query: '아', location: _location, radiusKm: 10);
    await tester.pump();
    controller.schedule(query: '아메리카노', location: _location, radiusKm: 10);
    await tester.pump();

    final CustomerStore latest = _store(
      id: 20,
      name: '최신 결과',
      type: 'LOCAL_STORE',
    );
    pending['아메리카노']!.complete(<CustomerStore>[latest]);
    await tester.pump();
    expect(controller.results.single.storeId, 20);

    pending['아']!.complete(<CustomerStore>[
      _store(id: 21, name: '오래된 결과', type: 'LOCAL_STORE'),
    ]);
    await tester.pump();
    expect(controller.results.single.storeId, 20);
  });

  testWidgets('검색어 clear는 예약 요청과 추천 결과를 초기화한다', (tester) async {
    final _SearchRepository repository = _SearchRepository(
      onSearch: (_) async => <CustomerStore>[
        _store(id: 30, name: '지워질 결과', type: 'LOCAL_STORE'),
      ],
    );
    final StoreSearchSuggestionController controller =
        StoreSearchSuggestionController(repository: repository);
    addTearDown(controller.dispose);

    controller.schedule(query: '지우기', location: _location, radiusKm: 10);
    controller.clear();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.queries, isEmpty);
    expect(controller.results, isEmpty);
    expect(controller.loading, isFalse);

    final StoreSearchSuggestionController loadedController =
        StoreSearchSuggestionController(
          repository: repository,
          debounceDuration: Duration.zero,
        );
    addTearDown(loadedController.dispose);
    loadedController.schedule(query: '지우기', location: _location, radiusKm: 10);
    await tester.pump();
    expect(loadedController.results, isNotEmpty);

    loadedController.clear();
    expect(loadedController.results, isEmpty);
    expect(loadedController.loading, isFalse);
  });

  testWidgets('추천 요청은 지도 stores를 유지하고 검색 확정 흐름만 지도 결과를 바꾼다', (tester) async {
    final CustomerStore mapStore = _store(
      id: 40,
      name: '기존 지도 업체',
      type: 'LOCAL_STORE',
    );
    final CustomerStore menuResult = _store(
      id: 41,
      name: '메뉴 검색 업체',
      type: 'LOCAL_STORE',
    );
    final _SearchRepository repository = _SearchRepository(
      onSearch: (query) async => query == '라떼'
          ? <CustomerStore>[menuResult]
          : <CustomerStore>[mapStore],
    );
    final StoreDiscoveryController mapController = StoreDiscoveryController(
      repository: repository,
      permissionGateway: MemoryCustomerPermissionGateway(),
    );
    final StoreSearchSuggestionController suggestionController =
        StoreSearchSuggestionController(
          repository: repository,
          debounceDuration: Duration.zero,
        );
    addTearDown(mapController.dispose);
    addTearDown(suggestionController.dispose);

    await mapController.initializeAtBusan();
    expect(mapController.stores.single.storeId, 40);

    suggestionController.schedule(
      query: '라떼',
      location: mapController.searchCenter,
      radiusKm: mapController.searchRadiusKm,
    );
    await tester.pump();
    await tester.pump();
    expect(suggestionController.results.single.storeId, 41);
    expect(mapController.stores.single.storeId, 40);

    await mapController.search(query: '라떼');
    expect(mapController.stores.single.storeId, 41);
  });

  test('추천 결과에 타입·영업중·마이픽 필터를 적용한다', () {
    final List<CustomerStore> stores = <CustomerStore>[
      _store(id: 50, name: 'LOCAL OPEN', type: 'LOCAL_STORE'),
      _store(
        id: 51,
        name: 'LOCAL PRE_OPEN',
        type: 'LOCAL_STORE',
        status: 'PRE_OPEN',
      ),
      _store(id: 52, name: 'EVENT OPEN', type: 'EVENT_COMMERCE'),
      _store(
        id: 53,
        name: 'EVENT PRE_OPEN',
        type: 'EVENT_COMMERCE',
        status: 'PRE_OPEN',
      ),
    ];

    expect(
      filterStoreSearchSuggestions(
        stores: stores,
        storeType: 'LOCAL_STORE',
      ).map((store) => store.storeId),
      <int>[50, 51],
    );
    expect(
      filterStoreSearchSuggestions(
        stores: stores,
        storeType: 'EVENT_COMMERCE',
      ).map((store) => store.storeId),
      <int>[52, 53],
    );
    expect(
      filterStoreSearchSuggestions(
        stores: stores,
        openOnly: true,
      ).map((store) => store.storeId),
      <int>[50, 52],
    );
    expect(
      filterStoreSearchSuggestions(
        stores: stores,
        favoritesOnly: true,
        favoriteStoreIds: const <int>{51, 52},
      ).map((store) => store.storeId),
      <int>[52, 51],
    );
  });

  test('영업중 필터는 OPEN 상태여도 공휴일 휴무인 업체를 제외한다', () {
    final CustomerStore holidayStore = _store(
      id: 54,
      name: '공휴일 휴무 매장',
      type: 'LOCAL_STORE',
      schedule: _publicHolidaySchedule(),
    );
    final CustomerStore ordinaryStore = _store(
      id: 55,
      name: '정상 영업 매장',
      type: 'LOCAL_STORE',
    );

    expect(
      filterStoreSearchSuggestions(
        stores: <CustomerStore>[holidayStore, ordinaryStore],
        openOnly: true,
      ).map((store) => store.storeId),
      <int>[55],
    );
  });

  testWidgets('EVENT 추천은 스토어명과 행사명을 서로 구분해 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: buildSearchSuggestionPanelForTest(<CustomerStore>[
              _store(
                id: 60,
                name: '모모 로스터스',
                type: 'EVENT_COMMERCE',
                eventName: '부산 커피 페스타',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('모모 로스터스'), findsOneWidget);
    expect(find.textContaining('부산 커피 페스타 · 행사·이벤트'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const CustomerLocation _location = CustomerLocation(
  latitude: 35.157778,
  longitude: 129.059167,
);

CustomerStore _store({
  required int id,
  required String name,
  required String type,
  String status = 'OPEN',
  String? eventName,
  CustomerStoreSchedule? schedule,
}) {
  return CustomerStore(
    storeId: id,
    storeType: type,
    name: name,
    eventName: eventName,
    businessStatus: status,
    openTime: '00:00:00',
    closeTime: '00:00:00',
    tags: const <String>[],
    schedule: schedule,
  );
}

CustomerStoreSchedule _publicHolidaySchedule() {
  const List<String> weekdays = <String>[
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  final DateTime koreaToday = DateTime.now().toUtc().add(
    const Duration(hours: 9),
  );
  final String evaluationDate =
      '${koreaToday.year.toString().padLeft(4, '0')}-'
      '${koreaToday.month.toString().padLeft(2, '0')}-'
      '${koreaToday.day.toString().padLeft(2, '0')}';
  return CustomerStoreSchedule.fromJson(<String, Object?>{
    'businessHours': <Object?>[
      for (final String day in weekdays)
        <String, Object?>{
          'dayOfWeek': day,
          'closed': false,
          'open24Hours': true,
        },
    ],
    'closureRules': const <Object?>[
      <String, Object?>{'ruleType': 'PUBLIC_HOLIDAY'},
    ],
    'scheduleExceptions': const <Object?>[],
    'publicHolidayAutoCalculationAvailable': true,
    'publicHolidayEvaluationDate': evaluationDate,
    'publicHoliday': true,
  });
}

class _SearchRepository implements StoreDiscoveryRepository {
  _SearchRepository({required this.onSearch});

  final Future<List<CustomerStore>> Function(String? query) onSearch;
  final List<String?> queries = <String?>[];

  @override
  Future<List<CustomerStore>> search({
    String? query,
    String? tag,
    CustomerLocation? location,
    double? radiusKm,
  }) {
    queries.add(query);
    return onSearch(query);
  }

  @override
  Future<CustomerStore> findDetail(int storeId) {
    throw UnimplementedError();
  }

  @override
  Future<StoreWalkingRoute> findWalkingRoute({
    required int storeId,
    required CustomerLocation startLocation,
  }) {
    throw UnimplementedError();
  }
}
