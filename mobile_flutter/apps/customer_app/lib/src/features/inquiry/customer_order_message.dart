import 'package:popq_app_core/popq_app_core.dart';

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

  factory CustomerOrderMessageSenderType.fromRealtime(
      PopqRealtimeMessageSenderType value,
      ) {
    return switch (value) {
      PopqRealtimeMessageSenderType.customer =>
      CustomerOrderMessageSenderType.customer,
      PopqRealtimeMessageSenderType.seller =>
      CustomerOrderMessageSenderType.seller,
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
    required this.clientMessageId,
    required this.content,
    required this.read,
    required this.readAt,
    required this.createdAt,
  });

  factory CustomerOrderMessage.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerOrderMessage(
      orderMessageId: _requiredInt(
        json,
        'orderMessageId',
      ),
      senderUserId: _requiredInt(
        json,
        'senderUserId',
      ),
      senderName: _requiredString(
        json,
        'senderName',
      ),
      senderType: CustomerOrderMessageSenderType.fromJson(
        _requiredString(
          json,
          'senderType',
        ),
      ),
      clientMessageId: _optionalString(
        json,
        'clientMessageId',
      ),
      content: _requiredString(
        json,
        'content',
      ),
      read: _requiredBool(
        json,
        'read',
      ),
      readAt: _optionalDateTime(
        json,
        'readAt',
      ),
      createdAt: _requiredDateTime(
        json,
        'createdAt',
      ),
    );
  }

  factory CustomerOrderMessage.fromRealtime(
      PopqRealtimeMessage message,
      ) {
    return CustomerOrderMessage(
      orderMessageId: message.orderMessageId,
      senderUserId: message.senderUserId,
      senderName: message.senderName,
      senderType:
      CustomerOrderMessageSenderType.fromRealtime(
        message.senderType,
      ),
      clientMessageId: message.clientMessageId,
      content: message.content,
      read: message.read,
      readAt: message.readAt,
      createdAt: message.createdAt,
    );
  }

  final int orderMessageId;
  final int senderUserId;
  final String senderName;
  final CustomerOrderMessageSenderType senderType;
  final String? clientMessageId;
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

  CustomerOrderMessage markAsRead(
      DateTime readAt,
      ) {
    return copyWith(
      read: true,
      readAt: readAt,
    );
  }

  CustomerOrderMessage copyWith({
    int? orderMessageId,
    int? senderUserId,
    String? senderName,
    CustomerOrderMessageSenderType? senderType,
    String? clientMessageId,
    String? content,
    bool? read,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return CustomerOrderMessage(
      orderMessageId:
      orderMessageId ?? this.orderMessageId,
      senderUserId:
      senderUserId ?? this.senderUserId,
      senderName:
      senderName ?? this.senderName,
      senderType:
      senderType ?? this.senderType,
      clientMessageId:
      clientMessageId ?? this.clientMessageId,
      content:
      content ?? this.content,
      read:
      read ?? this.read,
      readAt:
      readAt ?? this.readAt,
      createdAt:
      createdAt ?? this.createdAt,
    );
  }
}

class CustomerOrderMessagePage {
  const CustomerOrderMessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextBeforeMessageId,
  });

  factory CustomerOrderMessagePage.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerOrderMessagePage(
      messages:
      (json['messages'] as List<Object?>? ??
          const [])
          .map(
            (Object? item) =>
            CustomerOrderMessage.fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
            ),
      )
          .toList(growable: false),
      hasMore: _requiredBool(
        json,
        'hasMore',
      ),
      nextBeforeMessageId: _optionalInt(
        json,
        'nextBeforeMessageId',
      ),
    );
  }

  final List<CustomerOrderMessage> messages;
  final bool hasMore;
  final int? nextBeforeMessageId;
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
      orderPublicId: _requiredString(
        json,
        'orderPublicId',
      ),
      unreadCount: _requiredInt(
        json,
        'unreadCount',
      ),
    );
  }

  final String orderPublicId;
  final int unreadCount;

  bool get hasUnreadMessage {
    return unreadCount > 0;
  }
}

String _requiredString(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException(
    '$fieldName 필드는 비어 있지 않은 문자열이어야 합니다.',
  );
}

String? _optionalString(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is String) {
    final normalized = value.trim();

    return normalized.isEmpty
        ? null
        : normalized;
  }

  throw FormatException(
    '$fieldName 필드는 문자열이어야 합니다.',
  );
}

int _requiredInt(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value is num) {
    return value.toInt();
  }

  throw FormatException(
    '$fieldName 필드는 숫자여야 합니다.',
  );
}

int? _optionalInt(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException(
    '$fieldName 필드는 숫자여야 합니다.',
  );
}

bool _requiredBool(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value is bool) {
    return value;
  }

  throw FormatException(
    '$fieldName 필드는 true 또는 false여야 합니다.',
  );
}

DateTime _requiredDateTime(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException(
    '$fieldName 필드는 날짜 문자열이어야 합니다.',
  );
}

DateTime? _optionalDateTime(
    Map<String, Object?> json,
    String fieldName,
    ) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException(
    '$fieldName 필드는 날짜 문자열이어야 합니다.',
  );
}