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
    required this.enableNetworkLogs,
  });

  const AppEnvironment.local()
    : flavor = AppFlavor.development,
      apiBaseUrl = 'http://10.0.2.2:8082',
      enableNetworkLogs = true;

  factory AppEnvironment.fromEnvironment() {
    const flavor = String.fromEnvironment(
      'POPQ_FLAVOR',
      defaultValue: 'development',
    );
    const apiBaseUrl = String.fromEnvironment(
      'POPQ_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8082',
    );
    const enableNetworkLogs = bool.fromEnvironment(
      'POPQ_ENABLE_NETWORK_LOGS',
      defaultValue: true,
    );

    return AppEnvironment(
      flavor: AppFlavor.parse(flavor),
      apiBaseUrl: apiBaseUrl,
      enableNetworkLogs: enableNetworkLogs,
    );
  }

  final AppFlavor flavor;
  final String apiBaseUrl;
  final bool enableNetworkLogs;

  bool get isProduction => flavor == AppFlavor.production;
}
