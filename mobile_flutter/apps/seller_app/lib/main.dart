import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'src/seller_app.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'src/notifications/seller_push_notification_service.dart';

const naverClientId =
String.fromEnvironment('NAVER_CLIENT_ID');

const naverClientSecret =
String.fromEnvironment('NAVER_CLIENT_SECRET');

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp();

  debugPrint(
    'Seller 백그라운드 FCM 수신: ${message.messageId}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NaverLoginSDK.initialize(
    clientId: naverClientId,
    clientSecret: naverClientSecret,
    clientName: 'POPQ',
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await PushNotificationService.initialize();

  await KakaoSdk.init(
    nativeAppKey: '7711e4885b55fb01d710c364b08c069e',
  );

  runApp(
    PopqSellerApp(
      environment: AppEnvironment.fromEnvironment(),
    ),
  );
}