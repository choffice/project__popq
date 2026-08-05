import 'package:popq_app_core/popq_app_core.dart';

import 'customer_order_message.dart';

abstract interface class CustomerOrderMessageRepository {
  Future<List<CustomerOrderMessage>> findMessages(
    String orderPublicId,
  );

  Future<CustomerOrderMessagePage> findMessagePage(
    String orderPublicId, {
    int? beforeMessageId,
    int size = 30,
  });

  Future<CustomerOrderMessage> sendMessage({
    required String orderPublicId,
    required String content,
    String? clientMessageId,
  });

  Future<void> markMessagesAsRead({
    required String orderPublicId,
    required int lastReadMessageId,
  });

  Future<List<CustomerOrderUnreadMessageCount>>
      findUnreadMessageCounts();
}

class ApiCustomerOrderMessageRepository
    implements CustomerOrderMessageRepository {
  ApiCustomerOrderMessageRepository(
    this._apiClient,
  );

  final PopqApiClient _apiClient;

  @override
  Future<List<CustomerOrderMessage>> findMessages(
    String orderPublicId,
  ) {
    return _apiClient.get(
      '/api/v1/customer/orders/'
      '$orderPublicId/messages',
      decode: (Object? value) {
        return (value as List<Object?>)
            .map(
              (Object? item) => CustomerOrderMessage.fromJson(
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<CustomerOrderMessagePage> findMessagePage(
    String orderPublicId, {
    int? beforeMessageId,
    int size = 30,
  }) {
    if (size < 1 || size > 100) {
      throw ArgumentError.value(
        size,
        'size',
        'size는 1 이상 100 이하이어야 합니다.',
      );
    }

    if (beforeMessageId != null && beforeMessageId <= 0) {
      throw ArgumentError.value(
        beforeMessageId,
        'beforeMessageId',
        'beforeMessageId는 1 이상이어야 합니다.',
      );
    }

    return _apiClient.get(
      '/api/v1/customer/orders/'
      '$orderPublicId/messages/page',
      query: <String, Object?>{
        'size': size,
        if (beforeMessageId != null)
          'beforeMessageId': beforeMessageId,
      },
      decode: (Object? value) {
        return CustomerOrderMessagePage.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<CustomerOrderMessage> sendMessage({
    required String orderPublicId,
    required String content,
    String? clientMessageId,
  }) {
    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        '메시지 내용은 비어 있을 수 없습니다.',
      );
    }

    if (normalizedContent.length > 2000) {
      throw ArgumentError.value(
        content,
        'content',
        '메시지는 2,000자 이하이어야 합니다.',
      );
    }

    final normalizedClientMessageId = clientMessageId?.trim();

    if (normalizedClientMessageId != null &&
        normalizedClientMessageId.isEmpty) {
      throw ArgumentError.value(
        clientMessageId,
        'clientMessageId',
        'clientMessageId는 비어 있을 수 없습니다.',
      );
    }

    if (normalizedClientMessageId != null &&
        normalizedClientMessageId.length > 64) {
      throw ArgumentError.value(
        clientMessageId,
        'clientMessageId',
        'clientMessageId는 64자 이하이어야 합니다.',
      );
    }

    return _apiClient.post(
      '/api/v1/customer/orders/'
      '$orderPublicId/messages',
      body: <String, Object?>{
        'content': normalizedContent,
        if (normalizedClientMessageId != null)
          'clientMessageId': normalizedClientMessageId,
      },
      decode: (Object? value) {
        return CustomerOrderMessage.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<void> markMessagesAsRead({
    required String orderPublicId,
    required int lastReadMessageId,
  }) async {
    if (lastReadMessageId <= 0) {
      throw ArgumentError.value(
        lastReadMessageId,
        'lastReadMessageId',
        'lastReadMessageId는 1 이상이어야 합니다.',
      );
    }

    await _apiClient.post<bool>(
      '/api/v1/customer/orders/'
      '$orderPublicId/messages/read',
      body: <String, Object?>{
        'lastReadMessageId': lastReadMessageId,
      },
      decode: (Object? value) => value as bool,
    );
  }

  @override
  Future<List<CustomerOrderUnreadMessageCount>>
      findUnreadMessageCounts() {
    return _apiClient.get(
      '/api/v1/customer/orders/messages/'
      'unread-counts',
      decode: (Object? value) {
        return (value as List<Object?>)
            .map(
              (Object? item) =>
                  CustomerOrderUnreadMessageCount.fromJson(
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
            )
            .toList(growable: false);
      },
    );
  }
}
