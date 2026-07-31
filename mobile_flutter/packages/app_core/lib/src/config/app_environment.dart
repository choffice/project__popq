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
}