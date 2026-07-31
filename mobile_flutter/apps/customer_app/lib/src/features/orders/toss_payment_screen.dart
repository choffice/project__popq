import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TossPaymentResult {
  const TossPaymentResult.success({
    required this.paymentKey,
    required this.orderId,
    required this.amount,
  }) : success = true,
        errorCode = null,
        errorMessage = null;

  const TossPaymentResult.failure({
    required this.errorCode,
    required this.errorMessage,
  }) : success = false,
        paymentKey = null,
        orderId = null,
        amount = null;

  final bool success;

  final String? paymentKey;
  final String? orderId;
  final int? amount;

  final String? errorCode;
  final String? errorMessage;
}

class TossPaymentScreen extends StatefulWidget {
  const TossPaymentScreen({
    required this.clientKey,
    required this.orderId,
    required this.orderName,
    required this.amount,
    super.key,
  });

  final String clientKey;
  final String orderId;
  final String orderName;
  final int amount;

  @override
  State<TossPaymentScreen> createState() {
    return _TossPaymentScreenState();
  }
}

class _TossPaymentScreenState extends State<TossPaymentScreen> {
  static const String _successHost = 'success.popq.local';
  static const String _failHost = 'fail.popq.local';

  WebViewController? _controller;

  var _loading = true;
  var _completed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'PopqPayment',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted || _completed) {
              return;
            }

            setState(() {
              _loading = true;
            });
          },
          onPageFinished: (_) {
            if (!mounted || _completed) {
              return;
            }

            setState(() {
              _loading = false;
            });
          },
          onNavigationRequest: _handleNavigationRequest,
          onWebResourceError: (error) {
            if (_completed || error.isForMainFrame != true) {
              return;
            }

            if (!mounted) {
              return;
            }

            setState(() {
              _loading = false;
              _errorMessage =
              '결제 화면을 불러오지 못했습니다.\n'
                  '${error.description}';
            });
          },
        ),
      )
      ..loadHtmlString(
        _buildPaymentHtml(),
        baseUrl: 'https://pay.popq.local',
      );

    _controller = controller;
  }

  NavigationDecision _handleNavigationRequest(
      NavigationRequest request,
      ) {
    final uri = Uri.tryParse(request.url);

    if (uri == null) {
      return NavigationDecision.prevent;
    }

    if (uri.host == _successHost) {
      _handleSuccess(uri);
      return NavigationDecision.prevent;
    }

    if (uri.host == _failHost) {
      _handleFailure(uri);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleSuccess(Uri uri) {
    if (_completed) {
      return;
    }

    final paymentKey = uri.queryParameters['paymentKey'];
    final orderId = uri.queryParameters['orderId'];
    final amount = int.tryParse(
      uri.queryParameters['amount'] ?? '',
    );

    if (paymentKey == null ||
        paymentKey.isEmpty ||
        orderId == null ||
        amount == null) {
      _finish(
        const TossPaymentResult.failure(
          errorCode: 'INVALID_PAYMENT_RESULT',
          errorMessage: '토스 결제 결과가 올바르지 않습니다.',
        ),
      );
      return;
    }

    if (orderId != widget.orderId) {
      _finish(
        const TossPaymentResult.failure(
          errorCode: 'ORDER_ID_MISMATCH',
          errorMessage: '주문번호가 일치하지 않습니다.',
        ),
      );
      return;
    }

    if (amount != widget.amount) {
      _finish(
        const TossPaymentResult.failure(
          errorCode: 'PAYMENT_AMOUNT_MISMATCH',
          errorMessage: '결제 금액이 일치하지 않습니다.',
        ),
      );
      return;
    }

    _finish(
      TossPaymentResult.success(
        paymentKey: paymentKey,
        orderId: orderId,
        amount: amount,
      ),
    );
  }

  void _handleFailure(Uri uri) {
    if (_completed) {
      return;
    }

    final code =
        uri.queryParameters['code'] ??
            'TOSS_PAYMENT_FAILED';

    final message =
        uri.queryParameters['message'] ??
            '결제 인증에 실패했습니다.';

    _finish(
      TossPaymentResult.failure(
        errorCode: code,
        errorMessage: message,
      ),
    );
  }

  void _handleJavaScriptMessage(
      JavaScriptMessage message,
      ) {
    if (_completed) {
      return;
    }

    try {
      final json = Map<String, Object?>.from(
        jsonDecode(message.message) as Map,
      );

      final code =
          json['code']?.toString() ??
              'TOSS_JAVASCRIPT_ERROR';

      final errorMessage =
          json['message']?.toString() ??
              '토스 결제창을 실행하지 못했습니다.';

      _finish(
        TossPaymentResult.failure(
          errorCode: code,
          errorMessage: errorMessage,
        ),
      );
    } catch (_) {
      _finish(
        const TossPaymentResult.failure(
          errorCode: 'TOSS_JAVASCRIPT_ERROR',
          errorMessage: '토스 결제창 실행 중 오류가 발생했습니다.',
        ),
      );
    }
  }

  void _finish(TossPaymentResult result) {
    if (_completed) {
      return;
    }

    _completed = true;

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  String _buildPaymentHtml() {
    final clientKey = jsonEncode(widget.clientKey);

    final orderId = jsonEncode(widget.orderId);
    final orderName = jsonEncode(widget.orderName);

    final customerKey = jsonEncode(
      'popq-${DateTime.now().microsecondsSinceEpoch}',
    );

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
  >
  <title>POPQ 결제</title>

  <script src="https://js.tosspayments.com/v2/standard"></script>

  <style>
    html,
    body {
      width: 100%;
      height: 100%;
      margin: 0;
      background: #fffaf0;
      font-family: sans-serif;
    }

    .loading {
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #155e4b;
      font-size: 16px;
      font-weight: 700;
    }
  </style>
</head>

<body>
  <div class="loading">
    토스 결제창을 준비하고 있어요...
  </div>

  <script>
    async function startPayment() {
      try {
        const tossPayments = TossPayments($clientKey);

        const payment = tossPayments.payment({
          customerKey: $customerKey
        });

        await payment.requestPayment({
          method: "CARD",

          amount: {
            currency: "KRW",
            value: ${widget.amount}
          },

          orderId: $orderId,
          orderName: $orderName,

          successUrl:
            "https://$_successHost/payment",

          failUrl:
            "https://$_failHost/payment",

          windowTarget: "self"
        });
      } catch (error) {
        PopqPayment.postMessage(
          JSON.stringify({
            code:
              error.code ??
              "TOSS_PAYMENT_WINDOW_ERROR",

            message:
              error.message ??
              "토스 결제창을 열지 못했습니다."
          })
        );
      }
    }

    startPayment();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('토스 결제'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '현재 토스 결제 테스트는 '
                  'Android 앱에서 진행해주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('토스 결제'),
      ),
      body: Stack(
        children: [
          if (controller != null)
            WebViewWidget(
              controller: controller,
            ),

          if (_loading)
            const ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),

          if (_errorMessage != null)
            ColoredBox(
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _loading = true;
                          });

                          _controller?.loadHtmlString(
                            _buildPaymentHtml(),
                            baseUrl:
                            'https://pay.popq.local',
                          );
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}