import 'package:popq_app_core/popq_app_core.dart';

class CustomerNotification {
  const CustomerNotification({
    required this.notificationId,
    required this.type,
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.message,
    required this.deepLink,
    required this.read,
    required this.occurredAt,
  });

  factory CustomerNotification.fromJson(Map<String, Object?> json) {
    return CustomerNotification(
      notificationId: (json['notificationId'] as num).toInt(),
      type: json['type'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      deepLink: json['deepLink'] as String,
      read: json['read'] as bool,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }

  final int notificationId;
  final String type;
  final String targetType;
  final String targetId;
  final String title;
  final String message;
  final String deepLink;
  final bool read;
  final DateTime occurredAt;

  CustomerNotification copyWith({bool? read}) {
    return CustomerNotification(
      notificationId: notificationId,
      type: type,
      targetType: targetType,
      targetId: targetId,
      title: title,
      message: message,
      deepLink: deepLink,
      read: read ?? this.read,
      occurredAt: occurredAt,
    );
  }
}

class RegisteredPushDevice {
  const RegisteredPushDevice({required this.deviceId, required this.platform});

  factory RegisteredPushDevice.fromJson(Map<String, Object?> json) {
    return RegisteredPushDevice(
      deviceId: (json['deviceId'] as num).toInt(),
      platform: json['platform'] as String,
    );
  }

  final int deviceId;
  final String platform;
}

abstract interface class CustomerNotificationRepository {
  Future<List<CustomerNotification>> findAll({bool unreadOnly = false});

  Future<int> unreadCount();

  Future<CustomerNotification> markRead(int notificationId);

  Future<RegisteredPushDevice> registerDevice({
    required String token,
    required String platform,
  });

  Future<RegisteredPushDevice> unregisterDevice(int deviceId);
}

class ApiCustomerNotificationRepository
    implements CustomerNotificationRepository {
  ApiCustomerNotificationRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<List<CustomerNotification>> findAll({bool unreadOnly = false}) {
    return _apiClient.get(
      '/api/v1/customer/notifications',
      query: {'unreadOnly': unreadOnly},
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => CustomerNotification.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<int> unreadCount() {
    return _apiClient.get(
      '/api/v1/customer/notifications/unread-count',
      decode: (value) {
        final json = Map<String, Object?>.from(value as Map);
        return (json['unreadCount'] as num).toInt();
      },
    );
  }

  @override
  Future<CustomerNotification> markRead(int notificationId) {
    return _apiClient.post(
      '/api/v1/customer/notifications/$notificationId/read',
      decode: (value) => CustomerNotification.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<RegisteredPushDevice> registerDevice({
    required String token,
    required String platform,
  }) {
    return _apiClient.post(
      '/api/v1/customer/devices',
      body: {'token': token, 'platform': platform},
      decode: (value) => RegisteredPushDevice.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<RegisteredPushDevice> unregisterDevice(int deviceId) {
    return _apiClient.delete(
      '/api/v1/customer/devices/$deviceId',
      decode: (value) => RegisteredPushDevice.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }
}

class MemoryCustomerNotificationRepository
    implements CustomerNotificationRepository {
  MemoryCustomerNotificationRepository({
    List<CustomerNotification> notifications = const [],
  }) : _notifications = List.of(notifications);

  final List<CustomerNotification> _notifications;
  final List<RegisteredPushDevice> _devices = [];

  @override
  Future<List<CustomerNotification>> findAll({bool unreadOnly = false}) async {
    return _notifications
        .where((notification) => !unreadOnly || !notification.read)
        .toList();
  }

  @override
  Future<int> unreadCount() async {
    return _notifications.where((notification) => !notification.read).length;
  }

  @override
  Future<CustomerNotification> markRead(int notificationId) async {
    final index = _notifications.indexWhere(
      (notification) => notification.notificationId == notificationId,
    );
    final updated = _notifications[index].copyWith(read: true);
    _notifications[index] = updated;
    return updated;
  }

  @override
  Future<RegisteredPushDevice> registerDevice({
    required String token,
    required String platform,
  }) async {
    final device = RegisteredPushDevice(
      deviceId: _devices.length + 1,
      platform: platform,
    );
    _devices.add(device);
    return device;
  }

  @override
  Future<RegisteredPushDevice> unregisterDevice(int deviceId) async {
    final index = _devices.indexWhere((device) => device.deviceId == deviceId);
    return _devices.removeAt(index);
  }
}
