// only 개발용 웹 PC 고객 앱 입구

import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'src/customer_app.dart';
import 'src/features/permissions/customer_permission_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    PopqCustomerApp(
      environment: AppEnvironment.fromEnvironment(),

      // 웹 개발에서는 로그인 세션을 메모리에만 보관
      sessionStore: MemorySessionStore(),

      // 실제 PC GPS 대신 테스트용 고정 위치를 사용
      permissionGateway: MemoryCustomerPermissionGateway(
        location: const CustomerLocation(
          latitude: 35.157778,
          longitude: 129.059167,
        ),
      ),
    ),
  );
}