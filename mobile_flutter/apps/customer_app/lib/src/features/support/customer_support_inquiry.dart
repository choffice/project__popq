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
    required this.lastMessageAt,
    required this.createdAt,
    this.unreadMessageCount = 0,
  });

  factory CustomerSupportInquirySummary.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerSupportInquirySummary(
      supportInquiryId: (json['supportTicketId'] as num).toInt(),
      customerUserId: (json['requesterUserId'] as num).toInt(),
      customerName: json['requesterName'] as String,
      customerEmail: (json['requesterEmail'] as String?) ?? '',
      category: CustomerSupportCategory.fromJson(json['category']),
      title: json['subject'] as String,
      status: CustomerSupportStatus.fromJson(json['status']),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      unreadMessageCount:
      (json['unreadMessageCount'] as num?)?.toInt() ?? 0,
    );
  }

  final int supportInquiryId;
  final int customerUserId;
  final String customerName;
  final String customerEmail;
  final CustomerSupportCategory category;
  final String title;
  final CustomerSupportStatus status;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final int unreadMessageCount;

  bool get hasUnreadMessages => unreadMessageCount > 0;
}

class CustomerSupportInquiryMessage {
  const CustomerSupportInquiryMessage({
    required this.supportInquiryMessageId,
    required this.senderUserId,
    required this.senderName,
    required this.senderType,
    required this.content,
    required this.createdAt,
  });

  factory CustomerSupportInquiryMessage.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerSupportInquiryMessage(
      supportInquiryMessageId:
      (json['supportMessageId'] as num).toInt(),
      senderUserId: (json['senderUserId'] as num).toInt(),
      senderName: json['senderName'] as String,
      senderType: CustomerSupportSenderType.fromJson(
        json['senderType'],
      ),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int supportInquiryMessageId;
  final int senderUserId;
  final String senderName;
  final CustomerSupportSenderType senderType;
  final String content;
  final DateTime createdAt;

  bool get sentByCustomer {
    return senderType == CustomerSupportSenderType.requester;
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

  factory CustomerSupportInquiryDetail.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerSupportInquiryDetail(
      inquiry: CustomerSupportInquirySummary.fromJson(
        Map<String, Object?>.from(json['ticket'] as Map),
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