enum CustomerOrderMessageSenderType {
  customer,
  seller;

  factory CustomerOrderMessageSenderType.fromJson(
      String value,
      ) {
    return switch (value) {
      'CUSTOMER' => CustomerOrderMessageSenderType.customer,
      'SELLER' => CustomerOrderMessageSenderType.seller,
      _ => throw FormatException(
        '지원하지 않는 메시지 발신자 유형입니다: $value',
      ),
    };
  }

  String get apiValue {
    return switch (this) {
      CustomerOrderMessageSenderType.customer => 'CUSTOMER',
      CustomerOrderMessageSenderType.seller => 'SELLER',
    };
  }
}

class CustomerOrderMessage {
  const CustomerOrderMessage({
    required this.orderMessageId,
    required this.senderUserId,
    required this.senderName,
    required this.senderType,
    required this.content,
    required this.read,
    required this.readAt,
    required this.createdAt,
  });

  factory CustomerOrderMessage.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerOrderMessage(
      orderMessageId: (json['orderMessageId'] as num).toInt(),
      senderUserId: (json['senderUserId'] as num).toInt(),
      senderName: json['senderName'] as String,
      senderType: CustomerOrderMessageSenderType.fromJson(
        json['senderType'] as String,
      ),
      content: json['content'] as String,
      read: json['read'] as bool,
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(
        json['readAt'] as String,
      ),
      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),
    );
  }

  final int orderMessageId;
  final int senderUserId;
  final String senderName;
  final CustomerOrderMessageSenderType senderType;
  final String content;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get sentByCustomer {
    return senderType ==
        CustomerOrderMessageSenderType.customer;
  }

  bool get sentBySeller {
    return senderType ==
        CustomerOrderMessageSenderType.seller;
  }
}

class CustomerOrderUnreadMessageCount {
  const CustomerOrderUnreadMessageCount({
    required this.orderPublicId,
    required this.unreadCount,
  });

  factory CustomerOrderUnreadMessageCount.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerOrderUnreadMessageCount(
      orderPublicId: json['orderPublicId'] as String,
      unreadCount: (json['unreadCount'] as num).toInt(),
    );
  }

  final String orderPublicId;
  final int unreadCount;

  bool get hasUnreadMessage => unreadCount > 0;
}