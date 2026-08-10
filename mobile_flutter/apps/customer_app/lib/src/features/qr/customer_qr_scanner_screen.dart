import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'qr_webview_screen.dart';
import 'qr_url_resolver.dart';

class CustomerQrScannerScreen extends StatefulWidget {
  const CustomerQrScannerScreen({
    required this.apiBaseUrl,
    super.key,
  });

  final String apiBaseUrl;

  @override
  State<CustomerQrScannerScreen> createState() =>
      _CustomerQrScannerScreenState();
}

class _CustomerQrScannerScreenState
    extends State<CustomerQrScannerScreen> {
  bool _openingUrl = false;

  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_openingUrl || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue?.trim();

    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(rawValue);

    final isValidUrl =
        uri != null &&
            uri.host.isNotEmpty &&
            (uri.scheme == 'http' || uri.scheme == 'https');

    if (!isValidUrl) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text('올바른 URL 형식의 QR 코드가 아닙니다.'),
          ),
        );

      return;
    }

    _openingUrl = true;
    await _controller.stop();

    try {
      if (!mounted) {
        return;
      }

      final resolvedUrl = resolveQrWebUrl(
        scannedUrl: uri,
        apiBaseUrl: widget.apiBaseUrl,
      );

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            return QrWebViewScreen(
              url: resolvedUrl,
            );
          },
        ),
      );
    } finally {
      _openingUrl = false;

      if (mounted) {
        await _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: Text(
            'QR 코드를 사각형 안에 맞춰주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
