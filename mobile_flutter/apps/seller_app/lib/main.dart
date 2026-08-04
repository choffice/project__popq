import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'src/seller_app.dart';

const naverClientId =
String.fromEnvironment('NAVER_CLIENT_ID');

const naverClientSecret =
String.fromEnvironment('NAVER_CLIENT_SECRET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NaverLoginSDK.initialize(
    clientId: naverClientId,
    clientSecret: naverClientSecret,
    clientName: 'POPQ',
  );

  await Firebase.initializeApp();
  await KakaoSdk.init(
    nativeAppKey: '7711e4885b55fb01d710c364b08c069e',
  );

  runApp(
    PopqSellerApp(
      environment: AppEnvironment.fromEnvironment(),
    ),
  );
}