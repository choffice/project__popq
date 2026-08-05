import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

class SellerRealtimeScope
    extends InheritedNotifier<PopqRealtimeClient> {
  const SellerRealtimeScope({
    required PopqRealtimeClient client,
    required super.child,
    super.key,
  }) : super(notifier: client);

  PopqRealtimeClient get client {
    final value = notifier;

    if (value == null) {
      throw StateError(
        'SellerRealtimeScope에 실시간 클라이언트가 없습니다.',
      );
    }

    return value;
  }

  static PopqRealtimeClient of(
    BuildContext context,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
          SellerRealtimeScope
        >();

    if (scope == null) {
      throw StateError(
        'SellerRealtimeScope를 찾을 수 없습니다.',
      );
    }

    return scope.client;
  }

  static PopqRealtimeClient? maybeOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<
          SellerRealtimeScope
        >()
        ?.notifier;
  }
}
