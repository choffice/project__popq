import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'customer_app_badge_service.dart';

typedef PushDeepLinkHandler = void Function(String deepLink);

class PushNotificationService {
  const PushNotificationService._();

  static const AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
        'popq_chat_messages',
        'POPQ 문의 메시지',
        description: '고객과 판매자의 주문 문의 메시지 알림',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _silentChannel =
  AndroidNotificationChannel(
    'popq_silent_notifications',
    'POPQ 조용한 알림',
    description: '소리와 진동 없이 알림창과 앱 아이콘 배지만 표시합니다.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: true,
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

      debugPrint('Customer 알림 권한 상태: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await messaging.getToken();

      if (kDebugMode) {
        debugPrint('Customer FCM 토큰: $token');
      }

      messaging.onTokenRefresh.listen((refreshedToken) {
        if (kDebugMode) {
          debugPrint('Customer FCM 토큰 갱신: $refreshedToken');
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Customer FCM 초기화 실패: $error');
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
        ?.createNotificationChannel(_messageChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >()
        ?.createNotificationChannel(_silentChannel);

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();

    final launchPayload = launchDetails?.notificationResponse?.payload;

    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleLocalNotificationPayload(launchPayload);
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    await CustomerAppBadgeService
        .updateFromMessageData(message.data);

    final remoteNotification = message.notification;

    final isSilentNotification =
        remoteNotification?.android?.channelId ==
            _silentChannel.id;

    final title = remoteNotification?.title ?? message.data['title'];

    final body = remoteNotification?.body ?? message.data['body'];

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final notificationDetails = NotificationDetails(
      android: isSilentNotification
          ? const AndroidNotificationDetails(
        'popq_silent_notifications',
        'POPQ 조용한 알림',
        channelDescription:
        '소리와 진동 없이 알림창과 앱 아이콘 배지만 표시합니다.',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
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
    );

    await _localNotifications.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails:notificationDetails,
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
      debugPrint('Customer 알림 데이터 해석 실패: $error');
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
