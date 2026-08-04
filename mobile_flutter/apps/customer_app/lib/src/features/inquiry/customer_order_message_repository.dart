import 'package:popq_app_core/popq_app_core.dart';

import 'customer_order_message.dart';

abstract interface class CustomerOrderMessageRepository {
  Future<List<CustomerOrderMessage>> findMessages(
      String orderPublicId,
      );

  Future<CustomerOrderMessage> sendMessage({
    required String orderPublicId,
    required String content,
  });

  Future<List<CustomerOrderUnreadMessageCount>>
  findUnreadMessageCounts();
}

class ApiCustomerOrderMessageRepository
    implements CustomerOrderMessageRepository {
  ApiCustomerOrderMessageRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<List<CustomerOrderMessage>> findMessages(
      String orderPublicId,
      ) {
    return _apiClient.get(
      '/api/v1/customer/orders/$orderPublicId/messages',
      decode: (value) {
        return (value as List<Object?>)
            .map(
              (item) => CustomerOrderMessage.fromJson(
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
  Future<CustomerOrderMessage> sendMessage({
    required String orderPublicId,
    required String content,
  }) {
    return _apiClient.post(
      '/api/v1/customer/orders/$orderPublicId/messages',
      body: {
        'content': content.trim(),
      },
      decode: (value) {
        return CustomerOrderMessage.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<List<CustomerOrderUnreadMessageCount>>
  findUnreadMessageCounts() {
    return _apiClient.get(
      '/api/v1/customer/orders/messages/unread-counts',
      decode: (value) {
        return (value as List<Object?>)
            .map(
              (item) =>
              CustomerOrderUnreadMessageCount.fromJson(
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
        )
            .toList();
      },
    );
  }
}