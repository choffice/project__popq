import 'package:popq_app_core/popq_app_core.dart';

import 'seller_support_faq.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

abstract interface class SellerSupportRepository {
  Future<List<SellerSupportFaq>> getPopularFaqs();

  Future<List<SellerSupportFaq>> getFaqs({String? keyword});

  Future<SellerSupportTicketDetail> createTicket({
    required SellerSupportCategory category,
    required String subject,
    required String content,
  });

  Future<List<SellerSupportTicketSummary>> getMyTickets();

  Future<SellerSupportTicketDetail> getMyTicket(int supportTicketId);

  Future<SellerSupportTicketDetail> sendMessage({
    required int supportTicketId,
    required String content,
  });

  Future<SellerSupportTicketDetail> markTicketAsRead(int supportTicketId);
}

class ApiSellerSupportRepository implements SellerSupportRepository {
  ApiSellerSupportRepository(this._apiClient);

  final PopqApiClient _apiClient;

  static const String _ticketPath = '/api/v1/support/tickets';
  static const String _faqPath = '/api/v1/public/content/faqs';

  @override
  Future<List<SellerSupportFaq>> getPopularFaqs() async {
    final faqs = await _getPublishedFaqs();
    return List<SellerSupportFaq>.unmodifiable(faqs.take(4));
  }

  @override
  Future<List<SellerSupportFaq>> getFaqs({String? keyword}) async {
    final faqs = await _getPublishedFaqs();
    final normalizedKeyword = keyword?.trim().toLowerCase() ?? '';
    if (normalizedKeyword.isEmpty) {
      return List<SellerSupportFaq>.unmodifiable(faqs);
    }

    return List<SellerSupportFaq>.unmodifiable(
      faqs.where(
        (faq) =>
            faq.question.toLowerCase().contains(normalizedKeyword) ||
            faq.answer.toLowerCase().contains(normalizedKeyword) ||
            faq.category.toLowerCase().contains(normalizedKeyword),
      ),
    );
  }

  @override
  Future<SellerSupportTicketDetail> createTicket({
    required SellerSupportCategory category,
    required String subject,
    required String content,
  }) {
    final normalizedSubject = subject.trim();
    final normalizedContent = content.trim();
    _validateSubject(normalizedSubject);
    _validateContent(normalizedContent);

    return _apiClient.post(
      _ticketPath,
      body: <String, Object?>{
        'requesterType': 'SELLER',
        'category': category.apiValue,
        'subject': normalizedSubject,
        'content': normalizedContent,
      },
      decode: _decodeTicketDetail,
    );
  }

  @override
  Future<List<SellerSupportTicketSummary>> getMyTickets() {
    return _apiClient.get(
      _ticketPath,
      query: const <String, Object?>{'page': 0, 'size': 100},
      decode: (Object? value) {
        final json = Map<String, Object?>.from(value as Map);
        return (json['content'] as List<Object?>? ?? const <Object?>[])
            .map(
              (item) => SellerSupportTicketSummary.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<SellerSupportTicketDetail> getMyTicket(int supportTicketId) {
    _validateTicketId(supportTicketId);
    return _apiClient.get(
      '$_ticketPath/$supportTicketId',
      decode: _decodeTicketDetail,
    );
  }

  @override
  Future<SellerSupportTicketDetail> sendMessage({
    required int supportTicketId,
    required String content,
  }) {
    _validateTicketId(supportTicketId);
    final normalizedContent = content.trim();
    _validateContent(normalizedContent);

    return _apiClient.post(
      '$_ticketPath/$supportTicketId/messages',
      body: <String, Object?>{'content': normalizedContent},
      decode: _decodeTicketDetail,
    );
  }

  @override
  Future<SellerSupportTicketDetail> markTicketAsRead(int supportTicketId) {
    // The unified support-ticket API currently has no requester read endpoint.
    // Refreshing the detail keeps this method compatible with the screen while
    // the server continues to return an unread count of zero for requesters.
    return getMyTicket(supportTicketId);
  }

  Future<List<SellerSupportFaq>> _getPublishedFaqs() {
    return _apiClient.get(
      _faqPath,
      query: const <String, Object?>{'audience': 'SELLER_APP'},
      decode: (Object? value) {
        final faqs =
            (value as List<Object?>)
                .map(
                  (item) => SellerSupportFaq.fromJson(
                    Map<String, Object?>.from(item as Map),
                  ),
                )
                .toList(growable: false)
              ..sort(
                (left, right) =>
                    left.displayOrder.compareTo(right.displayOrder),
              );
        return faqs;
      },
    );
  }

  SellerSupportTicketDetail _decodeTicketDetail(Object? value) {
    return SellerSupportTicketDetail.fromJson(
      Map<String, Object?>.from(value as Map),
    );
  }

  void _validateTicketId(int supportTicketId) {
    if (supportTicketId <= 0) {
      throw ArgumentError.value(
        supportTicketId,
        'supportTicketId',
        '문의 번호는 1 이상이어야 합니다.',
      );
    }
  }

  void _validateSubject(String subject) {
    if (subject.isEmpty) {
      throw ArgumentError.value(subject, 'subject', '문의 제목을 입력해 주세요.');
    }
    if (subject.length > 200) {
      throw ArgumentError.value(subject, 'subject', '문의 제목은 200자 이하로 입력해 주세요.');
    }
  }

  void _validateContent(String content) {
    if (content.isEmpty) {
      throw ArgumentError.value(content, 'content', '문의 내용을 입력해 주세요.');
    }
    if (content.length > 4000) {
      throw ArgumentError.value(
        content,
        'content',
        '문의 내용은 4,000자 이하로 입력해 주세요.',
      );
    }
  }
}
