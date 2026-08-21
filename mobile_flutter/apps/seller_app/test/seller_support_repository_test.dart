import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_seller_app/src/features/support/seller_support_api_repository.dart';
import 'package:popq_seller_app/src/features/support/seller_support_repository.dart';
import 'package:popq_seller_app/src/features/support/seller_support_types.dart';

void main() {
  test('판매자 FAQ를 SELLER_APP 공개 콘텐츠 API에서 조회한다', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/public/content/faqs'
        '?audience=SELLER_APP',
      );
      return _successResponse(<Object?>[
        <String, Object?>{
          'faqId': 3,
          'audience': 'SELLER_APP',
          'category': 'APP',
          'question': '알림은 어디에서 설정하나요?',
          'answer': '마이 화면에서 설정할 수 있습니다.',
          'displayOrder': 1,
          'status': 'PUBLISHED',
        },
      ]);
    });
    final repository = _repository(client);

    final faqs = await repository.getPopularFaqs();

    expect(faqs, hasLength(1));
    expect(faqs.single.faqId, 3);
  });

  test('판매자 문의 생성 요청을 통합 지원 API 계약으로 보낸다', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/support/tickets',
      );
      expect(request.headers['authorization'], 'Bearer seller-token');
      expect(jsonDecode(request.body), <String, Object?>{
        'requesterType': 'SELLER',
        'category': 'OTHER',
        'subject': '앱 문의',
        'content': '알림이 오지 않습니다.',
      });
      return _successResponse(_ticketDetailJson());
    });
    final repository = _repository(client);

    final detail = await repository.createTicket(
      category: SellerSupportCategory.other,
      subject: ' 앱 문의 ',
      content: ' 알림이 오지 않습니다. ',
    );

    expect(detail.ticket.supportTicketId, 11);
    expect(detail.messages.single.sentBySeller, isTrue);
  });

  test('내 문의 페이지 응답에서 목록과 미읽음 개수를 추출한다', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/support/tickets?page=0&size=100',
      );
      return _successResponse(<String, Object?>{
        'content': <Object?>[
          _ticketSummaryJson(unreadMessageCount: 2),
        ],
        'page': 0,
        'size': 100,
        'totalElements': 1,
        'totalPages': 1,
        'first': true,
        'last': true,
      });
    });
    final repository = _repository(client);

    final tickets = await repository.getMyTickets();

    expect(tickets, hasLength(1));
    expect(tickets.single.subject, '앱 문의');
    expect(tickets.single.unreadMessageCount, 2);
    expect(tickets.single.hasUnreadMessages, isTrue);
  });

  test('문의 읽음 처리를 전용 API로 보낸다', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/support/tickets/11/read',
      );
      expect(request.headers['authorization'], 'Bearer seller-token');
      return _successResponse(
        _ticketDetailJson(unreadMessageCount: 0),
      );
    });
    final repository = _repository(client);

    final detail = await repository.markTicketAsRead(11);

    expect(detail.ticket.unreadMessageCount, 0);
    expect(detail.ticket.hasUnreadMessages, isFalse);
  });
}

ApiSellerSupportRepository _repository(http.Client client) {
  return ApiSellerSupportRepository(
    PopqApiClient(
      baseUrl: 'https://api.popq.test',
      accessTokenReader: () async => 'seller-token',
      httpClient: client,
    ),
  );
}

Map<String, Object?> _ticketDetailJson({int unreadMessageCount = 0}) {
  return <String, Object?>{
    'ticket': _ticketSummaryJson(
      unreadMessageCount: unreadMessageCount,
    ),
    'messages': <Object?>[
      <String, Object?>{
        'supportMessageId': 21,
        'senderUserId': 7,
        'senderName': '판매자',
        'senderType': 'REQUESTER',
        'content': '알림이 오지 않습니다.',
        'createdAt': '2026-08-14T00:00:00Z',
      },
    ],
  };
}

Map<String, Object?> _ticketSummaryJson({int unreadMessageCount = 0}) {
  return <String, Object?>{
    'supportTicketId': 11,
    'requesterUserId': 7,
    'requesterName': '판매자',
    'requesterEmail': 'seller@popq.test',
    'requesterType': 'SELLER',
    'category': 'OTHER',
    'subject': '앱 문의',
    'status': 'RECEIVED',
    'lastMessageAt': '2026-08-14T00:00:00Z',
    'createdAt': '2026-08-14T00:00:00Z',
    'unreadMessageCount': unreadMessageCount,
  };
}

http.Response _successResponse(Object? data) {
  return http.Response(
    jsonEncode(<String, Object?>{
      'success': true,
      'data': data,
      'error': null,
    }),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
