import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'src/seller_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PopqSellerApp(environment: AppEnvironment.fromEnvironment()));
}
