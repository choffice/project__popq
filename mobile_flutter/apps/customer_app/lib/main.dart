import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'src/customer_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(PopqCustomerApp(environment: AppEnvironment.fromEnvironment()));
}