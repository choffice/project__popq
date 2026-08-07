//only 개발용 웹pc 셀러 앱 입구

import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'src/seller_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    PopqSellerApp(
      environment: AppEnvironment.fromEnvironment(),
    ),
  );
}