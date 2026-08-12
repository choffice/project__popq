import 'customer_support_types.dart';

class CustomerSupportInquirySummary {
  const CustomerSupportInquirySummary({
    required this.supportInquiryId,
    required this.customerUserId,
    required this.customerName,
    required this.customerEmail,
    required this.category,
    required this.title,
    required this.status,
    required this.unreadMessageCount,
    required this.createdAt,
    required this.updatedAt,
    this.answeredAt,
    this.closedAt,
  });

  factory CustomerSupportInquirySummary.fromJson(Map<String, Object?> json) {
    return CustomerSupportInquirySummary(
      supportInquiryId: (json['supportInquiryId'] as num).toInt(),
      customerUserId: (json['customerUserId'] as num).toInt(),
      customerName: json['customerName'] as String,
      customerEmail: json['customerEmail'] as String,
      category: CustomerSupportCategory.fromJson(json['category']),
      title: json['title'] as String,
      status: CustomerSupportStatus.fromJson(json['status']),
      unreadMessageCount: (json['unreadMessageCount'] as num).toInt(),
      answeredAt: _parseDateTime(json['answeredAt']),
      closedAt: _parseDateTime(json['closedAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final int supportInquiryId;
  final int customerUserId;
  final String customerName;
  final String customerEmail;
  final CustomerSupportCategory category;
  final String title;
  final CustomerSupportStatus status;
  final int unreadMessageCount;
  final DateTime? answeredAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CustomerSupportInquiryMessage {
  const CustomerSupportInquiryMessage({
    required this.supportInquiryMessageId,
    required this.senderUserId,
    required this.senderName,
    required this.senderType,
    required this.content,
    required this.read,
    required this.createdAt,
    this.readAt,
  });

  factory CustomerSupportInquiryMessage.fromJson(Map<String, Object?> json) {
    return CustomerSupportInquiryMessage(
      supportInquiryMessageId: (json['supportInquiryMessageId'] as num).toInt(),
      senderUserId: (json['senderUserId'] as num).toInt(),
      senderName: json['senderName'] as String,
      senderType: CustomerSupportSenderType.fromJson(json['senderType']),
      content: json['content'] as String,
      read: json['read'] as bool,
      readAt: _parseDateTime(json['readAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int supportInquiryMessageId;
  final int senderUserId;
  final String senderName;
  final CustomerSupportSenderType senderType;
  final String content;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get sentByCustomer {
    return senderType == CustomerSupportSenderType.customer;
  }

  bool get sentByAdmin {
    return senderType == CustomerSupportSenderType.admin;
  }
}

class CustomerSupportInquiryDetail {
  const CustomerSupportInquiryDetail({
    required this.inquiry,
    required this.messages,
  });

  factory CustomerSupportInquiryDetail.fromJson(Map<String, Object?> json) {
    return CustomerSupportInquiryDetail(
      inquiry: CustomerSupportInquirySummary.fromJson(
        Map<String, Object?>.from(json['inquiry'] as Map),
      ),
      messages: (json['messages'] as List<Object?>)
          .map(
            (item) => CustomerSupportInquiryMessage.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final CustomerSupportInquirySummary inquiry;
  final List<CustomerSupportInquiryMessage> messages;
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}
