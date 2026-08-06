import 'package:popq_app_core/popq_app_core.dart';

class RegisteredSellerPushDevice {
  const RegisteredSellerPushDevice({
    required this.deviceId,
    required this.platform,
  });

  factory RegisteredSellerPushDevice.fromJson(Map<String, Object?> json) {
    return RegisteredSellerPushDevice(
      deviceId: (json['deviceId'] as num).toInt(),
      platform: json['platform'] as String,
    );
  }

  final int deviceId;
  final String platform;
}

class SellerPushDeviceRepository {
  const SellerPushDeviceRepository(this._apiClient);

  final PopqApiClient _apiClient;

  Future<RegisteredSellerPushDevice> registerDevice({
    required String token,
    required String platform,
  }) {
    return _apiClient.post(
      '/api/v1/seller/devices',
      body: {'token': token, 'platform': platform},
      decode: (value) {
        return RegisteredSellerPushDevice.fromJson(
          Map<String, Object?>.from(value as Map),
        );
      },
    );
  }
}
