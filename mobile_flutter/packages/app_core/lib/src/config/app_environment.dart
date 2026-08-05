import 'package:flutter/foundation.dart';

enum AppFlavor {
  development,
  staging,
  production;

  static AppFlavor parse(String value) {
    return switch (value.toLowerCase()) {
      'production' || 'prod' => AppFlavor.production,
      'staging' || 'stage' => AppFlavor.staging,
      _ => AppFlavor.development,
    };
  }
}

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.apiBaseUrl,
    required this.tossClientKey,
    required this.enableNetworkLogs,
  });

  const AppEnvironment.local()
      : flavor = AppFlavor.development,
        apiBaseUrl = 'http://10.0.2.2:8082',
        tossClientKey = '',
        enableNetworkLogs = true;

  factory AppEnvironment.fromEnvironment() {
    const flavor = String.fromEnvironment(
      'POPQ_FLAVOR',
      defaultValue: 'development',
    );

    const configuredApiBaseUrl = String.fromEnvironment(
      'POPQ_API_BASE_URL',
      defaultValue: '',
    );

    const tossClientKey = String.fromEnvironment(
      'POPQ_TOSS_CLIENT_KEY',
      defaultValue: '',
    );

    const enableNetworkLogs = bool.fromEnvironment(
      'POPQ_ENABLE_NETWORK_LOGS',
      defaultValue: true,
    );

    final apiBaseUrl = configuredApiBaseUrl.isNotEmpty
        ? configuredApiBaseUrl
        : kIsWeb
        ? 'http://localhost:8082'
        : 'http://10.0.2.2:8082';

    return AppEnvironment(
      flavor: AppFlavor.parse(flavor),
      apiBaseUrl: apiBaseUrl,
      tossClientKey: tossClientKey,
      enableNetworkLogs: enableNetworkLogs,
    );
  }

  final AppFlavor flavor;
  final String apiBaseUrl;
  final String tossClientKey;
  final bool enableNetworkLogs;

  bool get isProduction => flavor == AppFlavor.production;

  bool get hasTossClientKey => tossClientKey.trim().isNotEmpty;

  /**
   * 기존 POPQ_API_BASE_URL을 기준으로 WebSocket 주소를 만듭니다.
   *
   * http://192.168.0.10:8082
   * → ws://192.168.0.10:8082/ws
   *
   * https://api.example.com
   * → wss://api.example.com/ws
   */
  Uri get realtimeWebSocketUri {
    final normalizedBaseUrl = apiBaseUrl.trim();

    if (normalizedBaseUrl.isEmpty) {
      throw const FormatException(
        'POPQ_API_BASE_URL이 비어 있습니다.',
      );
    }

    final baseUri = Uri.parse(normalizedBaseUrl);

    if (!baseUri.hasScheme || baseUri.host.isEmpty) {
      throw FormatException(
        '올바르지 않은 POPQ_API_BASE_URL입니다: $apiBaseUrl',
      );
    }

    final webSocketScheme = switch (baseUri.scheme.toLowerCase()) {
      'http' => 'ws',
      'https' => 'wss',
      'ws' => 'ws',
      'wss' => 'wss',
      _ => throw FormatException(
        '지원하지 않는 API URL scheme입니다: ${baseUri.scheme}',
      ),
    };

    return baseUri.replace(
      scheme: webSocketScheme,
      path: '/ws',
      query: '',
      fragment: '',
    );
  }
}