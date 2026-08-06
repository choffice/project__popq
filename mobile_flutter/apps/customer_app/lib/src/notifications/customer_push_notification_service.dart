import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  const PushNotificationService._();

  static Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'Customer 알림 권한 상태: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus ==
          AuthorizationStatus.denied ||
          settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await messaging.getToken();

      if (kDebugMode) {
        debugPrint('Customer FCM 토큰: $token');
      }

      messaging.onTokenRefresh.listen((refreshedToken) {
        if (kDebugMode) {
          debugPrint(
            'Customer FCM 토큰 갱신: $refreshedToken',
          );
        }

        // 다음 단계에서 갱신된 토큰을 Spring 서버로 전송합니다.
      });
    } catch (error, stackTrace) {
      debugPrint('Customer FCM 초기화 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}