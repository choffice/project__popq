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

  final PopqApiClient _apiClient;

  @override
  Future<List<CustomerSupportFaq>> getPopularFaqs() {
    return _apiClient.get(
      '/api/v1/customer/support/faqs/popular',
      decode: _decodeFaqList,
    );
  }

  @override
  Future<List<CustomerSupportFaq>> getFaqs({String? keyword}) {
    final normalizedKeyword = keyword?.trim();

    return _apiClient.get(
      '/api/v1/customer/support/faqs',
      query: <String, Object?>{
        if (normalizedKeyword != null && normalizedKeyword.isNotEmpty)
          'keyword': normalizedKeyword,
      },
      decode: _decodeFaqList,
    );
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
      '/api/v1/customer/support/inquiries',
      body: <String, Object?>{
        'category': category.apiValue,
        'title': normalizedTitle,
        'content': normalizedContent,
      },
      decode: _decodeInquiryDetail,
    );
  }

  @override
  Future<List<CustomerSupportInquirySummary>> getMyInquiries() {
    return _apiClient.get(
      '/api/v1/customer/support/inquiries',
      decode: (Object? value) {
        return (value as List<Object?>)
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
      '/api/v1/customer/support/inquiries/'
      '$supportInquiryId',
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
      '/api/v1/customer/support/inquiries/'
      '$supportInquiryId/messages',
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
        '문의 ID는 1 이상이어야 합니다.',
      );
    }
  }

  void _validateTitle(String title) {
    if (title.isEmpty) {
      throw ArgumentError.value(title, 'title', '문의 제목을 입력해 주세요.');
    }

    if (title.length > 200) {
      throw ArgumentError.value(title, 'title', '문의 제목은 200자 이하여야 합니다.');
    }
  }

  void _validateContent(String content) {
    if (content.isEmpty) {
      throw ArgumentError.value(content, 'content', '문의 내용을 입력해 주세요.');
    }

    if (content.length > 3000) {
      throw ArgumentError.value(content, 'content', '문의 내용은 3,000자 이하여야 합니다.');
    }
  }
}
