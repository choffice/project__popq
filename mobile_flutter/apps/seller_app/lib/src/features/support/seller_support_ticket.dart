import 'seller_support_types.dart';

class SellerSupportTicketSummary {
  const SellerSupportTicketSummary({
    required this.supportTicketId,
    required this.requesterType,
    required this.category,
    required this.subject,
    required this.status,
    required this.lastMessageAt,
    required this.createdAt,
    required this.unreadMessageCount,
  });

  factory SellerSupportTicketSummary.fromJson(Map<String, Object?> json) {
    return SellerSupportTicketSummary(
      supportTicketId: (json['supportTicketId'] as num).toInt(),
      requesterType: json['requesterType'] as String,
      category: SellerSupportCategory.fromJson(json['category']),
      subject: json['subject'] as String,
      status: SellerSupportStatus.fromJson(json['status']),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      unreadMessageCount: (json['unreadMessageCount'] as num?)?.toInt() ?? 0,
    );
  }

  final int supportTicketId;
  final String requesterType;
  final SellerSupportCategory category;
  final String subject;
  final SellerSupportStatus status;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final int unreadMessageCount;

  bool get hasUnreadMessages => unreadMessageCount > 0;
}

class SellerSupportMessage {
  const SellerSupportMessage({
    required this.supportMessageId,
    required this.senderType,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory SellerSupportMessage.fromJson(Map<String, Object?> json) {
    return SellerSupportMessage(
      supportMessageId: (json['supportMessageId'] as num).toInt(),
      senderType: SellerSupportSenderType.fromJson(json['senderType']),
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: _parseNullableDateTime(json['readAt']),
    );
  }

  final int supportMessageId;
  final SellerSupportSenderType senderType;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get sentBySeller {
    return senderType == SellerSupportSenderType.seller;
  }

  bool get sentByAdmin {
    return senderType == SellerSupportSenderType.admin;
  }

  bool get isRead => readAt != null;
}

class SellerSupportTicketDetail {
  const SellerSupportTicketDetail({
    required this.ticket,
    required this.messages,
  });

  factory SellerSupportTicketDetail.fromJson(Map<String, Object?> json) {
    return SellerSupportTicketDetail(
      ticket: SellerSupportTicketSummary.fromJson(
        Map<String, Object?>.from(json['ticket'] as Map),
      ),
      messages: (json['messages'] as List<Object?>)
          .map(
            (message) => SellerSupportMessage.fromJson(
              Map<String, Object?>.from(message as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final SellerSupportTicketSummary ticket;
  final List<SellerSupportMessage> messages;
}

DateTime? _parseNullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}
