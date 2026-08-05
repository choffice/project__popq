import 'package:flutter/widgets.dart';
import 'package:popq_app_core/popq_app_core.dart';

class CustomerRealtimeScope
    extends InheritedNotifier<PopqRealtimeClient> {
  const CustomerRealtimeScope({
    required PopqRealtimeClient client,
    required super.child,
    super.key,
  }) : super(notifier: client);

  PopqRealtimeClient get client {
    final value = notifier;

    if (value == null) {
      throw StateError(
        'CustomerRealtimeScope에 실시간 클라이언트가 없습니다.',
      );
    }

    return value;
  }

  static PopqRealtimeClient of(
      BuildContext context,
      ) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<
        CustomerRealtimeScope>();

    if (scope == null) {
      throw StateError(
        'CustomerRealtimeScope를 찾을 수 없습니다.',
      );
    }

    return scope.client;
  }

  static PopqRealtimeClient? maybeOf(
      BuildContext context,
      ) {
    return context
        .dependOnInheritedWidgetOfExactType<
        CustomerRealtimeScope>()
        ?.notifier;
  }
}