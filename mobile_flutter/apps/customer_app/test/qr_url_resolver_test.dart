import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/qr/qr_url_resolver.dart';

void main() {
  group('resolveQrWebUrl', () {
    test('Android emulator에서 localhost를 호스트 PC 주소로 바꾼다', () {
      final resolved = resolveQrWebUrl(
        scannedUrl: Uri.parse(
          'http://localhost:5173/q/token-123?source=qr#menu',
        ),
        apiBaseUrl: 'http://10.0.2.2:8082',
      );

      expect(
        resolved,
        Uri.parse('http://10.0.2.2:5173/q/token-123?source=qr#menu'),
      );
    });

    test('실기기에서는 loopback 주소를 설정된 LAN 호스트로 바꾼다', () {
      final resolved = resolveQrWebUrl(
        scannedUrl: Uri.parse('http://127.0.0.1:5173/q/token-123'),
        apiBaseUrl: 'http://192.168.0.25:8082',
      );

      expect(
        resolved,
        Uri.parse('http://192.168.0.25:5173/q/token-123'),
      );
    });

    test('운영 QR의 공개 호스트는 변경하지 않는다', () {
      final scannedUrl = Uri.parse('https://order.example.com/q/token-123');

      final resolved = resolveQrWebUrl(
        scannedUrl: scannedUrl,
        apiBaseUrl: 'https://api.example.com',
      );

      expect(resolved, scannedUrl);
    });

    test('API 호스트도 loopback이면 원본 주소를 유지한다', () {
      final scannedUrl = Uri.parse('http://localhost:5173/q/token-123');

      final resolved = resolveQrWebUrl(
        scannedUrl: scannedUrl,
        apiBaseUrl: 'http://localhost:8082',
      );

      expect(resolved, scannedUrl);
    });
  });
}
