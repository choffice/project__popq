import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'src/customer_app.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';

const naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');
const naverClientSecret = String.fromEnvironment('NAVER_CLIENT_SECRET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverLoginSDK.initialize(
    clientId: naverClientId,
    clientSecret: naverClientSecret,
    clientName: 'POPQ',
  );
  await KakaoSdk.init(nativeAppKey: 'c4ae67811eeef68ede602afc04a8efbd',);
  await Firebase.initializeApp();
  runApp(PopqCustomerApp(environment: AppEnvironment.fromEnvironment()));
}