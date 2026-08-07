enum PopqRealtimeEventType {
  messageCreated,
  messageRead;

  factory PopqRealtimeEventType.fromJson(String value) {
    return switch (value) {
      'MESSAGE_CREATED' => PopqRealtimeEventType.messageCreated,
      'MESSAGE_READ' => PopqRealtimeEventType.messageRead,
      _ => throw FormatException('지원하지 않는 실시간 이벤트 유형입니다: $value'),
    };
  }

  String get apiValue {
    return switch (this) {
      PopqRealtimeEventType.messageCreated => 'MESSAGE_CREATED',
      PopqRealtimeEventType.messageRead => 'MESSAGE_READ',
    };
  }
}

enum PopqRealtimeMessageSenderType {
  customer,
  seller;

  factory PopqRealtimeMessageSenderType.fromJson(String value) {
    return switch (value) {
      'CUSTOMER' => PopqRealtimeMessageSenderType.customer,
      'SELLER' => PopqRealtimeMessageSenderType.seller,
      _ => throw FormatException('지원하지 않는 메시지 발신자 유형입니다: $value'),
    };
  }

  String get apiValue {
    return switch (this) {
      PopqRealtimeMessageSenderType.customer => 'CUSTOMER',
      PopqRealtimeMessageSenderType.seller => 'SELLER',
    };
  }
}

class PopqRealtimeMessage {
  const PopqRealtimeMessage({
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

  factory PopqRealtimeMessage.fromJson(Map<String, Object?> json) {
    return PopqRealtimeMessage(
      orderMessageId: _requiredInt(json, 'orderMessageId'),
      senderUserId: _requiredInt(json, 'senderUserId'),
      senderName: _requiredString(json, 'senderName'),
      senderType: PopqRealtimeMessageSenderType.fromJson(
        _requiredString(json, 'senderType'),
      ),
      clientMessageId: _optionalString(json, 'clientMessageId'),
      content: _requiredString(json, 'content'),
      read: _requiredBool(json, 'read'),
      readAt: _optionalDateTime(json, 'readAt'),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }

  final int orderMessageId;
  final int senderUserId;
  final String senderName;
  final PopqRealtimeMessageSenderType senderType;
  final String? clientMessageId;
  final String content;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get sentByCustomer {
    return senderType == PopqRealtimeMessageSenderType.customer;
  }

  bool get sentBySeller {
    return senderType == PopqRealtimeMessageSenderType.seller;
  }

  PopqRealtimeMessage copyWith({bool? read, DateTime? readAt}) {
    return PopqRealtimeMessage(
      orderMessageId: orderMessageId,
      senderUserId: senderUserId,
      senderName: senderName,
      senderType: senderType,
      clientMessageId: clientMessageId,
      content: content,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

class PopqRealtimeEvent {
  const PopqRealtimeEvent({
    required this.eventId,
    required this.eventType,
    required this.orderPublicId,
    required this.storeId,
    required this.customerUserId,
    required this.message,
    required this.readMessageIds,
    required this.readerType,
    required this.occurredAt,
  });

  factory PopqRealtimeEvent.fromJson(Map<String, Object?> json) {
    final rawMessage = json['message'];
    final rawReadMessageIds =
        json['readMessageIds'] as List<Object?>? ?? const [];

    return PopqRealtimeEvent(
      eventId: _requiredString(json, 'eventId'),
      eventType: PopqRealtimeEventType.fromJson(
        _requiredString(json, 'eventType'),
      ),
      orderPublicId: _requiredString(json, 'orderPublicId'),
      storeId: _requiredInt(json, 'storeId'),
      customerUserId: _optionalInt(json, 'customerUserId'),
      message: rawMessage == null
          ? null
          : PopqRealtimeMessage.fromJson(_requiredMap(rawMessage, 'message')),
      readMessageIds: rawReadMessageIds
          .map((Object? value) {
            if (value is num) {
              return value.toInt();
            }

            throw const FormatException('readMessageIds에는 숫자만 포함되어야 합니다.');
          })
          .toList(growable: false),
      readerType: _optionalSenderType(json, 'readerType'),
      occurredAt: _requiredDateTime(json, 'occurredAt'),
    );
  }

  final String eventId;
  final PopqRealtimeEventType eventType;
  final String orderPublicId;
  final int storeId;
  final int? customerUserId;
  final PopqRealtimeMessage? message;
  final List<int> readMessageIds;
  final PopqRealtimeMessageSenderType? readerType;
  final DateTime occurredAt;

  bool get isMessageCreated {
    return eventType == PopqRealtimeEventType.messageCreated;
  }

  bool get isMessageRead {
    return eventType == PopqRealtimeEventType.messageRead;
  }

  bool containsReadMessageId(int orderMessageId) {
    return readMessageIds.contains(orderMessageId);
  }
}

enum PopqOrderRealtimeEventType {
  placed,
  accepted,
  preparing,
  ready,
  completed,
  canceled,
  rejected,
  expired;

  factory PopqOrderRealtimeEventType.fromJson(String value) {
    return switch (value) {
      'ORDER_PLACED' => PopqOrderRealtimeEventType.placed,
      'ORDER_ACCEPTED' => PopqOrderRealtimeEventType.accepted,
      'ORDER_PREPARING' => PopqOrderRealtimeEventType.preparing,
      'ORDER_READY' => PopqOrderRealtimeEventType.ready,
      'ORDER_COMPLETED' => PopqOrderRealtimeEventType.completed,
      'ORDER_CANCELED' => PopqOrderRealtimeEventType.canceled,
      'ORDER_REJECTED' => PopqOrderRealtimeEventType.rejected,
      'ORDER_EXPIRED' => PopqOrderRealtimeEventType.expired,
      _ => throw FormatException('지원하지 않는 주문 실시간 이벤트 유형입니다: $value'),
    };
  }

  String get apiValue {
    return switch (this) {
      PopqOrderRealtimeEventType.placed => 'ORDER_PLACED',
      PopqOrderRealtimeEventType.accepted => 'ORDER_ACCEPTED',
      PopqOrderRealtimeEventType.preparing => 'ORDER_PREPARING',
      PopqOrderRealtimeEventType.ready => 'ORDER_READY',
      PopqOrderRealtimeEventType.completed => 'ORDER_COMPLETED',
      PopqOrderRealtimeEventType.canceled => 'ORDER_CANCELED',
      PopqOrderRealtimeEventType.rejected => 'ORDER_REJECTED',
      PopqOrderRealtimeEventType.expired => 'ORDER_EXPIRED',
    };
  }
}

class PopqOrderRealtimeEvent {
  const PopqOrderRealtimeEvent({
    required this.eventId,
    required this.eventType,
    required this.orderPublicId,
    required this.storeId,
    required this.guestSessionId,
    required this.userId,
    required this.previousStatus,
    required this.currentStatus,
    required this.occurredAt,
    required this.version,
  });

  factory PopqOrderRealtimeEvent.fromJson(Map<String, Object?> json) {
    return PopqOrderRealtimeEvent(
      eventId: _requiredString(json, 'eventId'),
      eventType: PopqOrderRealtimeEventType.fromJson(
        _requiredString(json, 'eventType'),
      ),
      orderPublicId: _requiredString(json, 'orderPublicId'),
      storeId: _requiredInt(json, 'storeId'),
      guestSessionId: _optionalInt(json, 'guestSessionId'),
      userId: _optionalInt(json, 'userId'),
      previousStatus: _optionalString(json, 'previousStatus'),
      currentStatus: _requiredString(json, 'currentStatus'),
      occurredAt: _requiredDateTime(json, 'occurredAt'),
      version: _requiredInt(json, 'version'),
    );
  }

  final String eventId;
  final PopqOrderRealtimeEventType eventType;
  final String orderPublicId;
  final int storeId;
  final int? guestSessionId;
  final int? userId;
  final String? previousStatus;
  final String currentStatus;
  final DateTime occurredAt;
  final int version;

  bool get isSignedInCustomerOrder => userId != null;

  bool get isGuestOrder => guestSessionId != null;

  bool isDuplicateOrOlderThan(int knownVersion) {
    return version <= knownVersion;
  }

  bool isNextVersionAfter(int knownVersion) {
    return version == knownVersion + 1;
  }

  bool hasVersionGapAfter(int knownVersion) {
    return version > knownVersion + 1;
  }
}

Map<String, Object?> _requiredMap(Object? value, String fieldName) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }

  throw FormatException('$fieldName 필드는 객체여야 합니다.');
}

String _requiredString(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('$fieldName 필드는 비어 있지 않은 문자열이어야 합니다.');
}

String? _optionalString(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is String) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  throw FormatException('$fieldName 필드는 문자열이어야 합니다.');
}

int _requiredInt(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('$fieldName 필드는 숫자여야 합니다.');
}

int? _optionalInt(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('$fieldName 필드는 숫자여야 합니다.');
}

bool _requiredBool(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value is bool) {
    return value;
  }

  throw FormatException('$fieldName 필드는 true 또는 false여야 합니다.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value is! String || value.isEmpty) {
    throw FormatException('$fieldName 필드는 날짜 문자열이어야 합니다.');
  }

  return DateTime.parse(value);
}

DateTime? _optionalDateTime(Map<String, Object?> json, String fieldName) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  throw FormatException('$fieldName 필드는 날짜 문자열이어야 합니다.');
}

PopqRealtimeMessageSenderType? _optionalSenderType(
  Map<String, Object?> json,
  String fieldName,
) {
  final value = json[fieldName];

  if (value == null) {
    return null;
  }

  if (value is String) {
    return PopqRealtimeMessageSenderType.fromJson(value);
  }

  throw FormatException('$fieldName 필드는 문자열이어야 합니다.');
}
