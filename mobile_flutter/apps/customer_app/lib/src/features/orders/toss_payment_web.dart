import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class TossPaymentWeb extends StatefulWidget {
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
  State<TossPaymentWeb> createState() =>
      _TossPaymentWebState();
}

class _TossPaymentWebState
    extends State<TossPaymentWeb> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe =
        element as web.HTMLIFrameElement;

        iframe.addEventListener(
          'popq-payment-success',
          ((web.Event _) {
            if (_completed) {
              return;
            }

            final rawResult =
            iframe.getAttribute(
              'data-payment-result',
            );

            if (rawResult == null ||
                rawResult.isEmpty) {
              _completeFailure(
                'INVALID_PAYMENT_RESULT',
                '토스 결제 결과가 비어 있습니다.',
              );
              return;
            }

            try {
              final decoded = jsonDecode(rawResult);

              if (decoded is! Map) {
                throw const FormatException(
                  '결제 결과 형식이 올바르지 않습니다.',
                );
              }

              final result =
              Map<String, Object?>.from(decoded);

              final paymentKey =
              result['paymentKey']?.toString();

              final orderId =
              result['orderId']?.toString();

              final rawAmount =
              result['amount'];

              final amount = rawAmount is num
                  ? rawAmount.toInt()
                  : int.tryParse(
                rawAmount?.toString() ?? '',
              );

              if (paymentKey == null ||
                  paymentKey.isEmpty ||
                  orderId == null ||
                  orderId.isEmpty ||
                  amount == null) {
                throw const FormatException(
                  '필수 결제 결과가 없습니다.',
                );
              }

              _completeSuccess(
                paymentKey,
                orderId,
                amount,
              );
            } catch (_) {
              _completeFailure(
                'INVALID_PAYMENT_RESULT',
                '토스 결제 결과를 확인하지 못했습니다.',
              );
            }
          }).toJS,
        );

        iframe.addEventListener(
          'popq-payment-failure',
          ((web.Event _) {
            if (_completed) {
              return;
            }

            final rawError =
            iframe.getAttribute(
              'data-payment-error',
            );

            if (rawError == null ||
                rawError.isEmpty) {
              _completeFailure(
                'TOSS_PAYMENT_ERROR',
                '토스 결제를 진행하지 못했습니다.',
              );
              return;
            }

            try {
              final decoded = jsonDecode(rawError);

              if (decoded is! Map) {
                throw const FormatException(
                  '결제 오류 형식이 올바르지 않습니다.',
                );
              }

              final error =
              Map<String, Object?>.from(decoded);

              _completeFailure(
                error['code']?.toString() ??
                    'TOSS_PAYMENT_ERROR',
                error['message']?.toString() ??
                    '토스 결제를 진행하지 못했습니다.',
              );
            } catch (_) {
              _completeFailure(
                'TOSS_PAYMENT_ERROR',
                '토스 결제를 진행하지 못했습니다.',
              );
            }
          }).toJS,
        );

        iframe
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..srcdoc = _buildPaymentHtml().toJS;
      },
    );
  }

  void _completeSuccess(
      String paymentKey,
      String orderId,
      int amount,
      ) {
    if (_completed) {
      return;
    }

    _completed = true;

    widget.onSuccess(
      paymentKey,
      orderId,
      amount,
    );
  }

  void _completeFailure(
      String errorCode,
      String errorMessage,
      ) {
    if (_completed) {
      return;
    }

    _completed = true;

    widget.onFailure(
      errorCode,
      errorMessage,
    );
  }

  String _buildPaymentHtml() {
    final clientKey = jsonEncode(widget.clientKey);
    final orderId = jsonEncode(widget.orderId);
    final orderName = jsonEncode(widget.orderName);

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">

  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
  >

  <script
    src="https://js.tosspayments.com/v2/standard"
  ></script>

  <style>
    html,
    body {
      width: 100%;
      height: 100%;
      margin: 0;
      background: #ffffff;
      font-family: sans-serif;
    }

    body {
      display: flex;
      align-items: center;
      justify-content: center;
    }

    #status {
      font-size: 15px;
      font-weight: 700;
    }
  </style>
</head>

<body>
  <div id="status">
    토스 결제창을 준비하고 있어요...
  </div>

  <script>
    async function startPayment() {
      const frame = window.frameElement;

      if (frame === null) {
        return;
      }

      try {
        const tossPayments =
            TossPayments($clientKey);

        const payment =
            tossPayments.payment({
              customerKey:
                  'popq-' + crypto.randomUUID()
            });

        const result =
            await payment.requestPayment({
              method: 'CARD',

              amount: {
                currency: 'KRW',
                value: ${widget.amount}
              },

              orderId: $orderId,
              orderName: $orderName,

              windowTarget: 'iframe'
            });

        frame.setAttribute(
          'data-payment-result',
          JSON.stringify(result)
        );

        frame.dispatchEvent(
          new Event('popq-payment-success')
        );
      } catch (error) {
        const failure = {
          code:
              error?.code ??
              'TOSS_PAYMENT_ERROR',

          message:
              error?.message ??
              '토스 결제를 진행하지 못했습니다.'
        };

        frame.setAttribute(
          'data-payment-error',
          JSON.stringify(failure)
        );

        frame.dispatchEvent(
          new Event('popq-payment-failure')
        );
      }
    }

    startPayment();
  </script>
</body>
</html>
''';
  }
}