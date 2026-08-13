import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'src/customer_app.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'src/notifications/customer_push_notification_service.dart';
import 'dart:ui';
import 'src/notifications/customer_app_badge_service.dart';
import 'package:flutter/foundation.dart';

const naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');
const naverClientSecret = String.fromEnvironment('NAVER_CLIENT_SECRET');

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  DartPluginRegistrant.ensureInitialized();

  await Firebase.initializeApp();

  await CustomerAppBadgeService
      .updateFromMessageData(message.data);

  debugPrint(
    'Customer 백그라운드 FCM 수신: '
        '${message.messageId}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NaverLoginSDK.initialize(
    clientId: naverClientId,
    clientSecret: naverClientSecret,
    clientName: 'POPQ',
  );
  await KakaoSdk.init(nativeAppKey: 'c4ae67811eeef68ede602afc04a8efbd',);

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await PushNotificationService.initialize();

  runApp(PopqCustomerApp(environment: AppEnvironment.fromEnvironment()));
}