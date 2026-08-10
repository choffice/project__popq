import 'package:flutter/material.dart';

class TossPaymentWeb extends StatelessWidget {
  const TossPaymentWeb({
    required this.clientKey,
    required this.orderId,
    required this.orderName,
    required this.amount,
    required this.onSuccess,
    required this.onFailure,
    super.key,
  });

  final String clientKey;
  final String orderId;
  final String orderName;
  final int amount;

  final void Function(
      String paymentKey,
      String orderId,
      int amount,
      ) onSuccess;

  final void Function(
      String errorCode,
      String errorMessage,
      ) onFailure;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}