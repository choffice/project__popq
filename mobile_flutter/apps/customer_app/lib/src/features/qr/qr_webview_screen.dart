import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QrWebViewScreen extends StatefulWidget {
  const QrWebViewScreen({
    required this.url,
    super.key,
  });

  final Uri url;

  @override
  State<QrWebViewScreen> createState() => _QrWebViewScreenState();
}

class _QrWebViewScreenState extends State<QrWebViewScreen> {
  late final WebViewController _controller;

  int _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }

            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }

            setState(() {
              _hasError = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) {
              return;
            }

            setState(() {
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('POPQ 주문'),
          actions: [
            IconButton(
              onPressed: () {
                _controller.reload();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_hasError)
              _WebViewError(
                onRetry: () {
                  _controller.loadRequest(widget.url);
                },
              )
            else
              WebViewWidget(
                controller: _controller,
              ),
            if (_loadingProgress < 100 && !_hasError)
              LinearProgressIndicator(
                value: _loadingProgress / 100,
              ),
          ],
        ),
      ),
    );
  }
}

class _WebViewError extends StatelessWidget {
  const _WebViewError({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              '페이지를 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '네트워크 상태와 QR 주소를 확인해주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}