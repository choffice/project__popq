import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'src/seller_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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