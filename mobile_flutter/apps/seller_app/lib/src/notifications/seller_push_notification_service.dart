import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef PushDeepLinkHandler = void Function(String deepLink);

class PushNotificationService {
  const PushNotificationService._();

  // Android는 생성된 알림 채널의 소리를 앱에서 변경할 수 없습니다.
  // 음원을 교체할 때 raw/popq_order_arrived.mp3를 바꾸고 채널 ID의
  // 버전(v1 -> v2)도 올려야 기존 설치 기기에서 새 소리가 적용됩니다.
  static const String _newOrderChannelId = 'popq_new_orders_v1';
  static const String _newOrderSoundResource = 'popq_order_arrived';

  static const AndroidNotificationChannel _newOrderChannel =
      AndroidNotificationChannel(
        _newOrderChannelId,
        'POPQ 새 주문',
        description: '새 주문이 접수되었을 때 재생되는 판매자 알림',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_newOrderSoundResource),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  static const AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
        'popq_chat_messages',
        'POPQ 문의 메시지',
        description: '고객과 판매자의 주문 문의 메시지 알림',
        importance: Importance.max,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static PushDeepLinkHandler? _deepLinkHandler;
  static String? _pendingDeepLink;

  static void setDeepLinkHandler(PushDeepLinkHandler handler) {
    _deepLinkHandler = handler;

    final pendingDeepLink = _pendingDeepLink;

    if (pendingDeepLink == null) {
      return;
    }

    _pendingDeepLink = null;
    handler(pendingDeepLink);
  }

  static void clearDeepLinkHandler() {
    _deepLinkHandler = null;
  }

  static Future<void> initialize() async {
    try {
      await _initializeLocalNotifications();

      final messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageOpened);

      final initialMessage = await messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleRemoteMessageOpened(initialMessage);
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Seller 알림 권한 상태: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await messaging.getToken();

      if (kDebugMode) {
        debugPrint('Seller FCM 토큰: $token');
      }

      messaging.onTokenRefresh.listen((refreshedToken) {
        if (kDebugMode) {
          debugPrint('Seller FCM 토큰 갱신: $refreshedToken');
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Seller FCM 초기화 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_popq'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationPayload(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_newOrderChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_messageChannel);

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();

    final launchPayload = launchDetails?.notificationResponse?.payload;

    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleLocalNotificationPayload(launchPayload);
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final remoteNotification = message.notification;

    final title = remoteNotification?.title ?? message.data['title'];

    final body = remoteNotification?.body ?? message.data['body'];

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final bool isNewOrder = message.data['type'] == 'ORDER_PLACED';

    await _localNotifications.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: isNewOrder
            ? const AndroidNotificationDetails(
                _newOrderChannelId,
                'POPQ 새 주문',
                channelDescription: '새 주문이 접수되었을 때 재생되는 판매자 알림',
                importance: Importance.max,
                priority: Priority.max,
                category: AndroidNotificationCategory.alarm,
                visibility: NotificationVisibility.public,
                playSound: true,
                sound: RawResourceAndroidNotificationSound(
                  _newOrderSoundResource,
                ),
                audioAttributesUsage: AudioAttributesUsage.alarm,
              )
            : const AndroidNotificationDetails(
                'popq_chat_messages',
                'POPQ 문의 메시지',
                channelDescription: '고객과 판매자의 주문 문의 메시지 알림',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.message,
                visibility: NotificationVisibility.public,
              ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleRemoteMessageOpened(RemoteMessage message) {
    _dispatchDeepLink(message.data['deepLink']);
  }

  static void _handleLocalNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map) {
        return;
      }

      _dispatchDeepLink(decoded['deepLink']);
    } catch (error) {
      debugPrint('Seller 알림 데이터 해석 실패: $error');
    }
  }

  static void _dispatchDeepLink(Object? value) {
    if (value is! String || value.isEmpty) {
      return;
    }

    final handler = _deepLinkHandler;

    if (handler == null) {
      _pendingDeepLink = value;
      return;
    }

    handler(value);
  }
}
