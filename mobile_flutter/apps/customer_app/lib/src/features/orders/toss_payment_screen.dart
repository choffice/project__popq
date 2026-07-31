import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
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
  /*
   * 토스 결제 인증 완료 후 이동할 임시 주소입니다.
   *
   * 실제 localhost:3000 서버를 실행하는 것은 아닙니다.
   * WebView가 해당 주소로 이동하려는 순간
   * NavigationDelegate에서 성공·실패 결과를 가로챕니다.
   */
  static const String _redirectOrigin = 'http://localhost:3000';
  static const String _successPath = '/success';
  static const String _failPath = '/fail';

  WebViewController? _controller;

  bool _loading = true;
  bool _completed = false;
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
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        Colors.white,
      )
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
              _errorMessage = null;
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
        baseUrl: '$_redirectOrigin/',
      );

    _controller = controller;
  }

  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request,
      ) async {
    final uri = Uri.tryParse(request.url);

    if (uri == null) {
      return NavigationDecision.prevent;
    }

    final isPopqRedirect =
        uri.scheme == 'http' &&
            uri.host == 'localhost' &&
            uri.port == 3000;

    /*
     * 토스 결제 인증 성공 결과를 가로챕니다.
     */
    if (isPopqRedirect && uri.path == _successPath) {
      _handleSuccess(uri);
      return NavigationDecision.prevent;
    }

    /*
     * 토스 결제 인증 실패 결과를 가로챕니다.
     */
    if (isPopqRedirect && uri.path == _failPath) {
      _handleFailure(uri);
      return NavigationDecision.prevent;
    }

    /*
     * 일반 웹 주소는 WebView 안에서 계속 엽니다.
     */
    if (uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'about' ||
        uri.scheme == 'data' ||
        uri.scheme == 'javascript') {
      return NavigationDecision.navigate;
    }

    /*
     * intent://, market://, 카드사 앱 스킴,
     * 토스 앱 스킴 등은 Android 외부 앱으로 전달합니다.
     */
    final launched = await _launchExternalPaymentUrl(
      request.url,
    );

    if (!launched && mounted) {
      setState(() {
        _loading = false;
        _errorMessage =
        '결제 앱을 실행하지 못했습니다.\n'
            '필요한 카드사 또는 결제 앱이 설치되어 있는지 '
            '확인해주세요.';
      });
    }

    return NavigationDecision.prevent;
  }

  Future<bool> _launchExternalPaymentUrl(
      String rawUrl,
      ) async {
    String? targetUrl = rawUrl;
    String? fallbackUrl;
    String? packageName;

    /*
     * Android intent URL은 앱 스킴, fallback URL,
     * 패키지명을 분리해서 처리합니다.
     */
    if (rawUrl.startsWith('intent:')) {
      final intentData = _parseIntentUrl(rawUrl);

      targetUrl = intentData.appUrl;
      fallbackUrl = intentData.fallbackUrl;
      packageName = intentData.packageName;
    }

    /*
     * 설치된 카드사·결제 앱을 먼저 실행합니다.
     */
    if (targetUrl != null && targetUrl.isNotEmpty) {
      try {
        final launched = await launchUrlString(
          targetUrl,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          return true;
        }
      } catch (error, stackTrace) {
        debugPrint(
          '외부 결제 앱 실행 실패: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    }

    /*
     * 앱이 설치되지 않았다면 토스가 전달한
     * 브라우저 fallback URL을 실행합니다.
     */
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      try {
        final launched = await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          return true;
        }
      } catch (error, stackTrace) {
        debugPrint(
          '결제 fallback URL 실행 실패: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    }

    /*
     * package 정보가 있다면 Play 스토어를 엽니다.
     */
    if (packageName != null && packageName.isNotEmpty) {
      try {
        final marketUrl =
            'market://details?id=$packageName';

        final marketLaunched = await launchUrlString(
          marketUrl,
          mode: LaunchMode.externalApplication,
        );

        if (marketLaunched) {
          return true;
        }
      } catch (error) {
        debugPrint(
          'Play 스토어 앱 실행 실패: $error',
        );
      }

      try {
        final playStoreUrl = Uri.parse(
          'https://play.google.com/store/apps/details'
              '?id=$packageName',
        );

        return launchUrl(
          playStoreUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Play 스토어 웹 실행 실패: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    }

    return false;
  }

  _IntentUrlData _parseIntentUrl(
      String rawUrl,
      ) {
    final markerIndex = rawUrl.indexOf(
      '#Intent;',
    );

    if (markerIndex < 0) {
      return const _IntentUrlData();
    }

    final targetPart = rawUrl.substring(
      0,
      markerIndex,
    );

    final optionPart = rawUrl.substring(
      markerIndex + '#Intent;'.length,
    );

    final scheme = _readIntentOption(
      optionPart,
      'scheme',
    );

    final packageName = _readIntentOption(
      optionPart,
      'package',
    );

    final encodedFallbackUrl = _readIntentOption(
      optionPart,
      'S.browser_fallback_url',
    );

    final fallbackUrl = encodedFallbackUrl == null
        ? null
        : Uri.decodeComponent(
      encodedFallbackUrl,
    );

    String? appUrl;

    if (targetPart.startsWith('intent://') &&
        scheme != null &&
        scheme.isNotEmpty) {
      final target = targetPart.substring(
        'intent://'.length,
      );

      appUrl = '$scheme://$target';
    } else if (targetPart.startsWith('intent:')) {
      final target = targetPart.substring(
        'intent:'.length,
      );

      if (target.contains('://')) {
        appUrl = target;
      } else if (scheme != null && scheme.isNotEmpty) {
        appUrl = '$scheme:$target';
      }
    }

    return _IntentUrlData(
      appUrl: appUrl,
      fallbackUrl: fallbackUrl,
      packageName: packageName,
    );
  }

  String? _readIntentOption(
      String optionPart,
      String key,
      ) {
    final pattern = RegExp(
      '(?:^|;)${RegExp.escape(key)}=([^;]+)',
    );

    return pattern
        .firstMatch(optionPart)
        ?.group(1);
  }

  void _handleSuccess(Uri uri) {
    if (_completed) {
      return;
    }

    final paymentKey =
    uri.queryParameters['paymentKey'];

    final orderId =
    uri.queryParameters['orderId'];

    final amount = int.tryParse(
      uri.queryParameters['amount'] ?? '',
    );

    if (paymentKey == null ||
        paymentKey.isEmpty ||
        orderId == null ||
        orderId.isEmpty ||
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
      final decoded = jsonDecode(
        message.message,
      );

      if (decoded is! Map) {
        throw const FormatException(
          '결제 오류 메시지 형식이 올바르지 않습니다.',
        );
      }

      final json = Map<String, Object?>.from(
        decoded,
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
    } catch (error, stackTrace) {
      debugPrint(
        '토스 JavaScript 오류 응답 처리 실패: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      _finish(
        const TossPaymentResult.failure(
          errorCode: 'TOSS_JAVASCRIPT_ERROR',
          errorMessage: '토스 결제창 실행 중 오류가 발생했습니다.',
        ),
      );
    }
  }

  void _finish(
      TossPaymentResult result,
      ) {
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
    final clientKey = jsonEncode(
      widget.clientKey,
    );

    final orderId = jsonEncode(
      widget.orderId,
    );

    final orderName = jsonEncode(
      widget.orderName,
    );

    final customerKey = jsonEncode(
      'popq-${DateTime.now().microsecondsSinceEpoch}',
    );

    final successUrl = jsonEncode(
      '$_redirectOrigin$_successPath',
    );

    final failUrl = jsonEncode(
      '$_redirectOrigin$_failPath',
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

          successUrl: $successUrl,
          failUrl: $failUrl,

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

  Future<void> _reloadPaymentPage() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _loading = true;
    });

    await _controller?.loadHtmlString(
      _buildPaymentHtml(),
      baseUrl: '$_redirectOrigin/',
    );
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

          if (_loading && _errorMessage == null)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          if (_errorMessage != null)
            Positioned.fill(
              child: ColoredBox(
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
                          onPressed: _reloadPaymentPage,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntentUrlData {
  const _IntentUrlData({
    this.appUrl,
    this.fallbackUrl,
    this.packageName,
  });

  final String? appUrl;
  final String? fallbackUrl;
  final String? packageName;
}