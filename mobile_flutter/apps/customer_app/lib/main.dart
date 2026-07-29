import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'src/customer_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PopqCustomerApp(environment: AppEnvironment.fromEnvironment()));
}
