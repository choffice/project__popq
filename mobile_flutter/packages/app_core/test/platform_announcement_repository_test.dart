import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  test('구매자 앱 대상 공지 목록을 공개 API에서 조회한다', () async {
    final httpClient = MockClient((http.Request request) async {
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/public/content/announcements'
        '?audience=CUSTOMER_APP',
      );
      return _successResponse(<Object?>[_announcementJson(id: 7)]);
    });
    final repository = ApiPlatformAnnouncementRepository(
      PopqApiClient(
        baseUrl: 'https://api.popq.test',
        accessTokenReader: () async => null,
        httpClient: httpClient,
      ),
      audience: PlatformAnnouncementAudience.customerApp,
    );

    final items = await repository.findAll();

    expect(items, hasLength(1));
    expect(items.single.platformAnnouncementId, 7);
    expect(items.single.title, '서비스 점검 안내');
  });

  test('판매자 앱 대상 공지 상세를 대상 파라미터와 함께 조회한다', () async {
    final httpClient = MockClient((http.Request request) async {
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/public/content/announcements/9'
        '?audience=SELLER_APP',
      );
      return _successResponse(_announcementJson(id: 9));
    });
    final repository = ApiPlatformAnnouncementRepository(
      PopqApiClient(
        baseUrl: 'https://api.popq.test',
        accessTokenReader: () async => null,
        httpClient: httpClient,
      ),
      audience: PlatformAnnouncementAudience.sellerApp,
    );

    final item = await repository.findOne(9);

    expect(item.platformAnnouncementId, 9);
    expect(item.displayDate, DateTime.parse('2026-08-13T00:00:00Z'));
  });

  test('게시 시작일이 없으면 생성일을 표시일로 사용한다', () {
    final json = _announcementJson(id: 11)..['publishStartAt'] = null;

    final item = PlatformAnnouncement.fromJson(json);

    expect(item.displayDate, DateTime.parse('2026-08-12T00:00:00Z'));
  });
}

Map<String, Object?> _announcementJson({required int id}) {
  return <String, Object?>{
    'platformAnnouncementId': id,
    'audience': 'ALL',
    'title': '서비스 점검 안내',
    'content': '점검 시간 동안 일부 기능이 제한됩니다.',
    'status': 'PUBLISHED',
    'publishStartAt': '2026-08-13T00:00:00Z',
    'publishEndAt': '2026-08-13T03:00:00Z',
    'authorName': '관리자',
    'createdAt': '2026-08-12T00:00:00Z',
    'updatedAt': '2026-08-12T01:00:00Z',
  };
}

http.Response _successResponse(Object? data) {
  return http.Response(
    jsonEncode(<String, Object?>{'success': true, 'data': data, 'error': null}),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
