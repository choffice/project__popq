import 'package:popq_app_core/popq_app_core.dart';

class SellerConversationSummary {
  const SellerConversationSummary({
    required this.orderPublicId,
    required this.customerUserId,
    required this.customerName,
    required this.orderStatus,
    required this.lastMessage,
    required this.lastMessageSenderType,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory SellerConversationSummary.fromJson(
    Map<String, Object?> json,
  ) {
    return SellerConversationSummary(
      orderPublicId: json['orderPublicId'] as String,
      customerUserId: (json['customerUserId'] as num?)?.toInt(),
      customerName: json['customerName'] as String,
      orderStatus: json['orderStatus'] as String,
      lastMessage: json['lastMessage'] as String,
      lastMessageSenderType:
          json['lastMessageSenderType'] as String,
      lastMessageAt: DateTime.parse(
        json['lastMessageAt'] as String,
      ),
      unreadCount: (json['unreadCount'] as num).toInt(),
    );
  }

  final String orderPublicId;
  final int? customerUserId;
  final String customerName;
  final String orderStatus;
  final String lastMessage;
  final String lastMessageSenderType;
  final DateTime lastMessageAt;
  final int unreadCount;

  bool get hasUnreadMessage => unreadCount > 0;

  bool get lastMessageSentByCustomer {
    return lastMessageSenderType == 'CUSTOMER';
  }
}

class SellerConversationDetail {
  const SellerConversationDetail({
    required this.orderPublicId,
    required this.storeId,
    required this.storeName,
    required this.customerUserId,
    required this.customerName,
    required this.orderType,
    required this.orderStatus,
    required this.totalAmount,
    required this.orderedAt,
    required this.orderItems,
    required this.messages,
  });

  factory SellerConversationDetail.fromJson(
    Map<String, Object?> json,
  ) {
    return SellerConversationDetail(
      orderPublicId: json['orderPublicId'] as String,
      storeId: (json['storeId'] as num).toInt(),
      storeName: json['storeName'] as String,
      customerUserId: (json['customerUserId'] as num?)?.toInt(),
      customerName: json['customerName'] as String,
      orderType: json['orderType'] as String,
      orderStatus: json['orderStatus'] as String,
      totalAmount: (json['totalAmount'] as num).toInt(),
      orderedAt: DateTime.parse(
        json['orderedAt'] as String,
      ),
      orderItems: (json['orderItems'] as List<Object?>? ?? const [])
          .map(
            (Object? item) => SellerConversationOrderItem.fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
            ),
          )
          .toList(),
      messages: (json['messages'] as List<Object?>? ?? const [])
          .map(
            (Object? item) => SellerOrderMessage.fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
            ),
          )
          .toList(),
    );
  }

  final String orderPublicId;
  final int storeId;
  final String storeName;
  final int? customerUserId;
  final String customerName;
  final String orderType;
  final String orderStatus;
  final int totalAmount;
  final DateTime orderedAt;
  final List<SellerConversationOrderItem> orderItems;
  final List<SellerOrderMessage> messages;

  int get totalQuantity {
    return orderItems.fold<int>(
      0,
      (int total, SellerConversationOrderItem item) {
        return total + item.quantity;
      },
    );
  }
}

class SellerConversationOrderItem {
  const SellerConversationOrderItem({
    required this.orderItemId,
    required this.productName,
    required this.quantity,
    required this.itemTotalPrice,
  });

  factory SellerConversationOrderItem.fromJson(
    Map<String, Object?> json,
  ) {
    return SellerConversationOrderItem(
      orderItemId: (json['orderItemId'] as num).toInt(),
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      itemTotalPrice: (json['itemTotalPrice'] as num).toInt(),
    );
  }

  final int orderItemId;
  final String productName;
  final int quantity;
  final int itemTotalPrice;
}

class SellerOrderMessage {
  const SellerOrderMessage({
    required this.orderMessageId,
    required this.senderUserId,
    required this.senderName,
    required this.senderType,
    required this.content,
    required this.read,
    required this.readAt,
    required this.createdAt,
  });

  factory SellerOrderMessage.fromJson(
    Map<String, Object?> json,
  ) {
    return SellerOrderMessage(
      orderMessageId: (json['orderMessageId'] as num).toInt(),
      senderUserId: (json['senderUserId'] as num).toInt(),
      senderName: json['senderName'] as String,
      senderType: json['senderType'] as String,
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
  final String senderType;
  final String content;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get sentBySeller => senderType == 'SELLER';

  bool get sentByCustomer => senderType == 'CUSTOMER';
}

class SellerOrderMessagePage {
  const SellerOrderMessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextBeforeMessageId,
  });

  factory SellerOrderMessagePage.fromJson(
    Map<String, Object?> json,
  ) {
    return SellerOrderMessagePage(
      messages: (json['messages'] as List<Object?>? ?? const [])
          .map(
            (Object? item) => SellerOrderMessage.fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
            ),
          )
          .toList(),
      hasMore: json['hasMore'] as bool,
      nextBeforeMessageId:
          (json['nextBeforeMessageId'] as num?)?.toInt(),
    );
  }

  final List<SellerOrderMessage> messages;
  final bool hasMore;
  final int? nextBeforeMessageId;
}

abstract interface class SellerCustomerRepository {
  Future<List<SellerConversationSummary>> findConversations(
    int storeId,
  );

  Future<SellerConversationDetail> findConversation(
    int storeId,
    String orderPublicId,
  );

  Future<SellerConversationDetail> findConversationMetadata(
    int storeId,
    String orderPublicId,
  );

  Future<SellerOrderMessagePage> findMessagePage(
    int storeId,
    String orderPublicId, {
    int? beforeMessageId,
    int size = 30,
  });

  Future<SellerOrderMessage> sendMessage(
    int storeId,
    String orderPublicId, {
    required String content,
  });

  Future<int> countUnreadMessages(
    int storeId,
  );
}

class ApiSellerCustomerRepository
    implements SellerCustomerRepository {
  ApiSellerCustomerRepository(
    this._apiClient,
  );

  final PopqApiClient _apiClient;

  String _basePath(int storeId) {
    return '/api/v1/seller/stores/$storeId';
  }

  @override
  Future<List<SellerConversationSummary>> findConversations(
    int storeId,
  ) {
    return _apiClient.get(
      '${_basePath(storeId)}/conversations',
      decode: (Object? value) {
        return (value as List<Object?>)
            .map(
              (Object? item) =>
                  SellerConversationSummary.fromJson(
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<SellerConversationDetail> findConversation(
    int storeId,
    String orderPublicId,
  ) {
    return _apiClient.get(
      '${_basePath(storeId)}/orders/'
      '$orderPublicId/messages',
      decode: (Object? value) {
        return SellerConversationDetail.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<SellerConversationDetail> findConversationMetadata(
    int storeId,
    String orderPublicId,
  ) {
    return _apiClient.get(
      '${_basePath(storeId)}/orders/'
      '$orderPublicId/conversation',
      decode: (Object? value) {
        return SellerConversationDetail.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<SellerOrderMessagePage> findMessagePage(
    int storeId,
    String orderPublicId, {
    int? beforeMessageId,
    int size = 30,
  }) {
    return _apiClient.get(
      '${_basePath(storeId)}/orders/'
      '$orderPublicId/messages/page',
      query: <String, Object?>{
        'size': size,
        if (beforeMessageId != null)
          'beforeMessageId': beforeMessageId,
      },
      decode: (Object? value) {
        return SellerOrderMessagePage.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<SellerOrderMessage> sendMessage(
    int storeId,
    String orderPublicId, {
    required String content,
  }) {
    final String normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        '메시지를 입력해 주세요.',
      );
    }

    if (normalizedContent.length > 2000) {
      throw ArgumentError.value(
        content,
        'content',
        '메시지는 2,000자 이하로 입력해 주세요.',
      );
    }

    return _apiClient.post(
      '${_basePath(storeId)}/orders/'
      '$orderPublicId/messages',
      body: <String, Object?>{
        'content': normalizedContent,
      },
      decode: (Object? value) {
        return SellerOrderMessage.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<int> countUnreadMessages(
    int storeId,
  ) {
    return _apiClient.get(
      '${_basePath(storeId)}/'
      'conversations/unread-count',
      decode: (Object? value) {
        return (value as num).toInt();
      },
    );
  }
}
