import 'package:popq_app_core/popq_app_core.dart';

import 'customer_support_faq.dart';
import 'customer_support_inquiry.dart';
import 'customer_support_types.dart';

abstract interface class CustomerSupportRepository {
  Future<List<CustomerSupportFaq>> getPopularFaqs();

  Future<List<CustomerSupportFaq>> getFaqs({String? keyword});

  Future<CustomerSupportInquiryDetail> createInquiry({
    required CustomerSupportCategory category,
    required String title,
    required String content,
  });

  Future<List<CustomerSupportInquirySummary>> getMyInquiries();

  Future<CustomerSupportInquiryDetail> getMyInquiry(int supportInquiryId);

  Future<CustomerSupportInquiryDetail> sendMessage({
    required int supportInquiryId,
    required String content,
  });
}

class ApiCustomerSupportRepository implements CustomerSupportRepository {
  ApiCustomerSupportRepository(this._apiClient);

  static const String _ticketPath = '/api/v1/support/tickets';
  static const String _faqPath = '/api/v1/public/content/faqs';

  final PopqApiClient _apiClient;

  @override
  Future<List<CustomerSupportFaq>> getPopularFaqs() {
    return getFaqs();
  }

  @override
  Future<List<CustomerSupportFaq>> getFaqs({String? keyword}) async {
    final faqs = await _apiClient.get(
      _faqPath,
      query: const <String, Object?>{'audience': 'CUSTOMER_APP'},
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
  Future<CustomerSupportInquiryDetail> createInquiry({
    required CustomerSupportCategory category,
    required String title,
    required String content,
  }) {
    final normalizedTitle = title.trim();
    final normalizedContent = content.trim();

    _validateTitle(normalizedTitle);
    _validateContent(normalizedContent);

    return _apiClient.post(
      _ticketPath,
      body: <String, Object?>{
        'requesterType': 'CUSTOMER',
        'category': category.apiValue,
        'subject': normalizedTitle,
        'content': normalizedContent,
      },
      decode: _decodeInquiryDetail,
    );
  }

  @override
  Future<List<CustomerSupportInquirySummary>> getMyInquiries() {
    return _apiClient.get(
      _ticketPath,
      query: const <String, Object?>{'page': 0, 'size': 100},
      decode: (Object? value) {
        final page = Map<String, Object?>.from(value as Map);

        final content = page['content'] as List<Object?>;

        return content
            .map(
              (item) => CustomerSupportInquirySummary.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<CustomerSupportInquiryDetail> getMyInquiry(int supportInquiryId) {
    _validateInquiryId(supportInquiryId);

    return _apiClient.get(
      '$_ticketPath/$supportInquiryId',
      decode: _decodeInquiryDetail,
    );
  }

  @override
  Future<CustomerSupportInquiryDetail> sendMessage({
    required int supportInquiryId,
    required String content,
  }) {
    _validateInquiryId(supportInquiryId);

    final normalizedContent = content.trim();
    _validateContent(normalizedContent);

    return _apiClient.post(
      '$_ticketPath/$supportInquiryId/messages',
      body: <String, Object?>{'content': normalizedContent},
      decode: _decodeInquiryDetail,
    );
  }

  List<CustomerSupportFaq> _decodeFaqList(Object? value) {
    return (value as List<Object?>)
        .map(
          (item) => CustomerSupportFaq.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  CustomerSupportInquiryDetail _decodeInquiryDetail(Object? value) {
    return CustomerSupportInquiryDetail.fromJson(
      Map<String, Object?>.from(value as Map),
    );
  }

  void _validateInquiryId(int supportInquiryId) {
    if (supportInquiryId <= 0) {
      throw ArgumentError.value(
        supportInquiryId,
        'supportInquiryId',
        '문의 번호는 1 이상이어야 합니다.',
      );
    }
  }

  void _validateTitle(String title) {
    if (title.isEmpty) {
      throw ArgumentError('문의 제목을 입력해 주세요.');
    }

    if (title.length > 200) {
      throw ArgumentError('문의 제목은 200자 이하로 입력해 주세요.');
    }
  }

  void _validateContent(String content) {
    if (content.isEmpty) {
      throw ArgumentError('문의 내용을 입력해 주세요.');
    }

    if (content.length > 4000) {
      throw ArgumentError('문의 내용은 4,000자 이하로 입력해 주세요.');
    }
  }
}
