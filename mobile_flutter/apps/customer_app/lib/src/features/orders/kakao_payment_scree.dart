import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KakaoPaymentResult {
  const KakaoPaymentResult.success({
    required this.paymentId,
    required this.orderPublicId,
    required this.pgToken,
  }) : success = true,
        canceled = false,
        errorCode = null,
        errorMessage = null;

  const KakaoPaymentResult.canceled({
    required this.paymentId,
    required this.orderPublicId,
  }) : success = false,
        canceled = true,
        pgToken = null,
        errorCode = 'KAKAO_PAYMENT_CANCELED',
        errorMessage = '카카오페이 결제가 취소되었습니다.';

  const KakaoPaymentResult.failure({
    required this.paymentId,
    required this.orderPublicId,
    required this.errorCode,
    required this.errorMessage,
  }) : success = false,
        canceled = false,
        pgToken = null;

  final bool success;
  final bool canceled;

  final int paymentId;
  final String orderPublicId;

  final String? pgToken;

  final String? errorCode;
  final String? errorMessage;
}

class KakaoPaymentScreen extends StatefulWidget {
  const KakaoPaymentScreen({
    required this.redirectUrl,
    required this.orderPublicId,
    required this.paymentId,
    this.approvalPath = '/kakao/success',
    this.cancelPath = '/kakao/cancel',
    this.failPath = '/kakao/fail',
    super.key,
  });

  final String redirectUrl;
  final String orderPublicId;
  final int paymentId;

  /*
   * Spring Boot의 카카오페이 callback URL 경로와
   * 동일하게 설정해야 합니다.
   *
   * 호스트는 실제 등록 도메인이나 개발용 주소를 사용할 수 있으며,
   * Flutter에서는 경로와 주문·결제 식별자를 검증합니다.
   */
  final String approvalPath;
  final String cancelPath;
  final String failPath;

  @override
  State<KakaoPaymentScreen> createState() {
    return _KakaoPaymentScreenState();
  }
}

class _KakaoPaymentScreenState extends State<KakaoPaymentScreen> {
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
    final redirectUri = Uri.tryParse(
      widget.redirectUrl,
    );

    if (redirectUri == null ||
        !redirectUri.hasScheme ||
        widget.redirectUrl.trim().isEmpty) {
      _errorMessage =
      '카카오페이 결제 이동 주소가 올바르지 않습니다.';
      _loading = false;
      return;
    }

    final controller =
    WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        Colors.white,
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
          onNavigationRequest:
          _handleNavigationRequest,
          onWebResourceError: (error) {
            if (_completed ||
                error.isForMainFrame != true ||
                !mounted) {
              return;
            }

            setState(() {
              _loading = false;
              _errorMessage =
              '카카오페이 결제 화면을 '
                  '불러오지 못했습니다.\n'
                  '${error.description}';
            });
          },
        ),
      )
      ..loadRequest(redirectUri);

    _controller = controller;
  }

  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request,
      ) async {
    final uri = Uri.tryParse(request.url);

    if (uri == null) {
      return NavigationDecision.prevent;
    }

    if (_isCallbackPath(
      uri,
      widget.approvalPath,
    )) {
      _handleApproval(uri);

      return NavigationDecision.prevent;
    }

    if (_isCallbackPath(
      uri,
      widget.cancelPath,
    )) {
      _handleCancel(uri);

      return NavigationDecision.prevent;
    }

    if (_isCallbackPath(
      uri,
      widget.failPath,
    )) {
      _handleFailure(uri);

      return NavigationDecision.prevent;
    }

    if (_isWebNavigation(uri)) {
      return NavigationDecision.navigate;
    }

    /*
     * kakaotalk://, intent://, market:// 등
     * 웹 주소가 아닌 결제 앱 스킴은 외부 앱으로 전달합니다.
     */
    final launched =
    await _launchExternalPaymentUrl(
      request.url,
    );

    if (!launched && mounted && !_completed) {
      setState(() {
        _loading = false;
        _errorMessage =
        '카카오페이 앱을 실행하지 못했습니다.\n'
            '카카오톡 또는 카카오페이 앱이 '
            '설치되어 있는지 확인해주세요.';
      });
    }

    return NavigationDecision.prevent;
  }

  bool _isCallbackPath(
      Uri uri,
      String expectedPath,
      ) {
    return _normalizePath(uri.path) ==
        _normalizePath(expectedPath);
  }

  String _normalizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }

    var normalized =
    path.startsWith('/') ? path : '/$path';

    while (normalized.length > 1 &&
        normalized.endsWith('/')) {
      normalized = normalized.substring(
        0,
        normalized.length - 1,
      );
    }

    return normalized;
  }

  bool _isWebNavigation(Uri uri) {
    return uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'about' ||
        uri.scheme == 'data' ||
        uri.scheme == 'javascript';
  }

  void _handleApproval(Uri uri) {
    if (_completed) {
      return;
    }

    final validationError =
    _validateCallbackIdentity(uri);

    if (validationError != null) {
      _finish(
        KakaoPaymentResult.failure(
          paymentId: widget.paymentId,
          orderPublicId:
          widget.orderPublicId,
          errorCode:
          'KAKAO_CALLBACK_MISMATCH',
          errorMessage: validationError,
        ),
      );

      return;
    }

    final pgToken =
    uri.queryParameters['pg_token'];

    if (pgToken == null ||
        pgToken.trim().isEmpty) {
      _finish(
        KakaoPaymentResult.failure(
          paymentId: widget.paymentId,
          orderPublicId:
          widget.orderPublicId,
          errorCode:
          'KAKAO_PG_TOKEN_MISSING',
          errorMessage:
          '카카오페이 승인 토큰을 '
              '받지 못했습니다.',
        ),
      );

      return;
    }

    _finish(
      KakaoPaymentResult.success(
        paymentId: widget.paymentId,
        orderPublicId:
        widget.orderPublicId,
        pgToken: pgToken,
      ),
    );
  }

  void _handleCancel(Uri uri) {
    if (_completed) {
      return;
    }

    final validationError =
    _validateCallbackIdentity(uri);

    if (validationError != null) {
      _finish(
        KakaoPaymentResult.failure(
          paymentId: widget.paymentId,
          orderPublicId:
          widget.orderPublicId,
          errorCode:
          'KAKAO_CALLBACK_MISMATCH',
          errorMessage: validationError,
        ),
      );

      return;
    }

    _finish(
      KakaoPaymentResult.canceled(
        paymentId: widget.paymentId,
        orderPublicId:
        widget.orderPublicId,
      ),
    );
  }

  void _handleFailure(Uri uri) {
    if (_completed) {
      return;
    }

    final validationError =
    _validateCallbackIdentity(uri);

    if (validationError != null) {
      _finish(
        KakaoPaymentResult.failure(
          paymentId: widget.paymentId,
          orderPublicId:
          widget.orderPublicId,
          errorCode:
          'KAKAO_CALLBACK_MISMATCH',
          errorMessage: validationError,
        ),
      );

      return;
    }

    final errorCode =
        uri.queryParameters['error_code'] ??
            uri.queryParameters['code'] ??
            'KAKAO_PAYMENT_FAILED';

    final errorMessage =
        uri.queryParameters['error_message'] ??
            uri.queryParameters['message'] ??
            '카카오페이 결제 인증에 실패했습니다.';

    _finish(
      KakaoPaymentResult.failure(
        paymentId: widget.paymentId,
        orderPublicId:
        widget.orderPublicId,
        errorCode: errorCode,
        errorMessage: errorMessage,
      ),
    );
  }

  String? _validateCallbackIdentity(Uri uri) {
    final callbackOrderPublicId =
    uri.queryParameters['orderPublicId'];

    final callbackPaymentId = int.tryParse(
      uri.queryParameters['paymentId'] ?? '',
    );

    if (callbackOrderPublicId == null ||
        callbackOrderPublicId.isEmpty) {
      return '카카오페이 콜백에 주문번호가 없습니다.';
    }

    if (callbackOrderPublicId !=
        widget.orderPublicId) {
      return '카카오페이 콜백의 주문번호가 '
          '현재 주문과 일치하지 않습니다.';
    }

    if (callbackPaymentId == null) {
      return '카카오페이 콜백에 결제번호가 없습니다.';
    }

    if (callbackPaymentId != widget.paymentId) {
      return '카카오페이 콜백의 결제번호가 '
          '현재 결제와 일치하지 않습니다.';
    }

    return null;
  }

  Future<bool> _launchExternalPaymentUrl(
      String rawUrl,
      ) async {
    String? targetUrl = rawUrl;
    String? fallbackUrl;
    String? packageName;

    if (rawUrl.startsWith('intent:')) {
      final intentData =
      _parseIntentUrl(rawUrl);

      targetUrl = intentData.appUrl;
      fallbackUrl =
          intentData.fallbackUrl;
      packageName =
          intentData.packageName;
    }

    if (targetUrl != null &&
        targetUrl.isNotEmpty) {
      try {
        final launched =
        await launchUrlString(
          targetUrl,
          mode:
          LaunchMode.externalApplication,
        );

        if (launched) {
          return true;
        }
      } catch (error, stackTrace) {
        debugPrint(
          '카카오페이 외부 앱 실행 실패: $error',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    }

    if (fallbackUrl != null &&
        fallbackUrl.isNotEmpty) {
      try {
        final launched = await launchUrl(
          Uri.parse(fallbackUrl),
          mode:
          LaunchMode.externalApplication,
        );

        if (launched) {
          return true;
        }
      } catch (error, stackTrace) {
        debugPrint(
          '카카오페이 fallback URL 실행 실패: '
              '$error',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    }

    if (packageName != null &&
        packageName.isNotEmpty) {
      final marketUrl =
          'market://details?id=$packageName';

      try {
        final launched =
        await launchUrlString(
          marketUrl,
          mode:
          LaunchMode.externalApplication,
        );

        if (launched) {
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
          mode:
          LaunchMode.externalApplication,
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
    final markerIndex =
    rawUrl.indexOf('#Intent;');

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

    final encodedFallbackUrl =
    _readIntentOption(
      optionPart,
      'S.browser_fallback_url',
    );

    final fallbackUrl =
    encodedFallbackUrl == null
        ? null
        : Uri.decodeComponent(
      encodedFallbackUrl,
    );

    String? appUrl;

    if (targetPart.startsWith(
      'intent://',
    ) &&
        scheme != null &&
        scheme.isNotEmpty) {
      final target = targetPart.substring(
        'intent://'.length,
      );

      appUrl = '$scheme://$target';
    } else if (targetPart.startsWith(
      'intent:',
    )) {
      final target = targetPart.substring(
        'intent:'.length,
      );

      if (target.contains('://')) {
        appUrl = target;
      } else if (scheme != null &&
          scheme.isNotEmpty) {
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

  void _finish(KakaoPaymentResult result) {
    if (_completed) {
      return;
    }

    _completed = true;

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  Future<void> _reloadPaymentPage() async {
    final redirectUri = Uri.tryParse(
      widget.redirectUrl,
    );

    if (redirectUri == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    await _controller?.loadRequest(
      redirectUri,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('카카오페이 결제'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '카카오페이 결제 테스트는 '
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
        title: const Text('카카오페이 결제'),
      ),
      body: Stack(
        children: [
          if (controller != null)
            WebViewWidget(
              controller: controller,
            ),

          if (_loading &&
              _errorMessage == null)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              ),
            ),

          if (_errorMessage != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      24,
                    ),
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        Text(
                          _errorMessage!,
                          textAlign:
                          TextAlign.center,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        FilledButton(
                          onPressed:
                          _reloadPaymentPage,
                          child: const Text(
                            '다시 시도',
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop();
                          },
                          child: const Text(
                            '결제 화면 닫기',
                          ),
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