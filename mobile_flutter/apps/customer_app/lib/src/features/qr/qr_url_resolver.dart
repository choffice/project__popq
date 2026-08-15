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

String? qrTokenFromUrl(Uri uri) {
  final segments = uri.pathSegments;
  for (var index = 0; index < segments.length - 1; index += 1) {
    if (segments[index] == 'q' && segments[index + 1].isNotEmpty) {
      return segments[index + 1];
    }
  }
  return null;
}

bool _isLoopbackHost(String host) {
  final normalizedHost = host.toLowerCase();
  return normalizedHost == 'localhost' ||
      normalizedHost == '::1' ||
      normalizedHost.startsWith('127.');
}
