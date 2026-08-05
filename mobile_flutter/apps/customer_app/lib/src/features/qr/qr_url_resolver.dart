Uri resolveQrWebUrl({
  required Uri scannedUrl,
  required String apiBaseUrl,
}) {
  if (!_isLoopbackHost(scannedUrl.host)) {
    return scannedUrl;
  }

  final apiUri = Uri.tryParse(apiBaseUrl);
  if (apiUri == null ||
      apiUri.host.isEmpty ||
      _isLoopbackHost(apiUri.host)) {
    return scannedUrl;
  }

  return scannedUrl.replace(host: apiUri.host);
}

bool _isLoopbackHost(String host) {
  final normalizedHost = host.toLowerCase();
  return normalizedHost == 'localhost' ||
      normalizedHost == '::1' ||
      normalizedHost.startsWith('127.');
}
