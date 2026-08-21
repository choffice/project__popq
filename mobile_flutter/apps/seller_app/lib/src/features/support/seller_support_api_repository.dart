import 'package:popq_app_core/popq_app_core.dart';

import 'seller_support_faq.dart';
import 'seller_support_repository.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

class ApiSellerSupportRepository implements SellerSupportRepository {
  ApiSellerSupportRepository(this._apiClient);

  static const String _ticketPath = '/api/v1/support/tickets';
  static const String _faqPath = '/api/v1/public/content/faqs';

  final PopqApiClient _apiClient;

  @override
  Future<List<SellerSupportFaq>> getPopularFaqs() {
    return getFaqs();
  }

  @override
  Future<List<SellerSupportFaq>> getFaqs({String? keyword}) async {
    final faqs = await _apiClient.get(
      _faqPath,
      query: const <String, Object?>{
        'audience': 'SELLER_APP',
      },
      decode: _decodeFaqList,
    );

    final normalizedKeyword = keyword?.trim().toLowerCase();

    if (normalizedKeyword == null || normalizedKeyword.isEmpty) {
      return faqs;
    }

    return faqs
        .where(
          (faq) =>
              faq.question.toLowerCase().contains(normalizedKeyword) ||
              faq.answer.toLowerCase().contains(normalizedKeyword) ||
              faq.category.toLowerCase().contains(normalizedKeyword),
        )
        .toList(growable: false);
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
      decode: (value) {
        final page = Map<String, Object?>.from(value as Map);
        final content = page['content'] as List<Object?>;

        return content
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
    _validateTicketId(supportTicketId);

    return _apiClient.post(
      '$_ticketPath/$supportTicketId/read',
      decode: _decodeTicketDetail,
    );
  }

  List<SellerSupportFaq> _decodeFaqList(Object? value) {
    return (value as List<Object?>)
        .map(
          (item) => SellerSupportFaq.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList(growable: false);
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
      throw ArgumentError('문의 제목을 입력해 주세요.');
    }

    if (subject.length > 200) {
      throw ArgumentError('문의 제목은 200자 이하로 입력해 주세요.');
    }
  }

  void _validateContent(String content) {
    if (content.isEmpty) {
      throw ArgumentError('문의 내용을 입력해 주세요.');
    }

    if (content.length > 4000) {
      throw ArgumentError('문의 내용은 4000자 이하로 입력해 주세요.');
    }
  }
}
