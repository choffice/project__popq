import 'dart:typed_data';

import 'package:popq_app_core/popq_app_core.dart';

class SellerIdentity {
  const SellerIdentity({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    this.profileImageUrl,
    this.phone,
  });

  factory SellerIdentity.fromJson(
    Map<String, Object?> json, {
    String? imageBaseUrl,
  }) {
    return SellerIdentity(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      profileImageUrl: _resolveImageUrl(
        json['profileImageUrl'] as String?,
        imageBaseUrl,
      ),
      phone: json['phone'] as String?,
    );
  }

  final int userId;
  final String email;
  final String name;
  final String role;
  final String? profileImageUrl;
  final String? phone;

  bool get isSeller => role == 'SELLER';

  SellerIdentity copyWith({String? profileImageUrl}) {
    return SellerIdentity(
      userId: userId,
      email: email,
      name: name,
      role: role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phone: phone,
    );
  }
}

abstract interface class SellerIdentityRepository {
  Future<SellerIdentity> getCurrent();

  Future<String> uploadProfileImage(String filePath);

  Future<String> uploadProfileImageBytes(
    Uint8List bytes, {
    required String fileName,
  });
}

class ApiSellerIdentityRepository implements SellerIdentityRepository {
  ApiSellerIdentityRepository(this._apiClient, {this.imageBaseUrl = ''});

  final PopqApiClient _apiClient;
  final String imageBaseUrl;

  @override
  Future<SellerIdentity> getCurrent() {
    return _apiClient.get(
      '/api/v1/auth/me',
      decode: (value) => SellerIdentity.fromJson(
        Map<String, Object?>.from(value as Map),
        imageBaseUrl: imageBaseUrl,
      ),
    );
  }

  @override
  Future<String> uploadProfileImage(String filePath) {
    return _apiClient.postMultipartFile<String>(
      '/api/v1/users/me/profile-image',
      fieldName: 'file',
      filePath: filePath,
      decode: (value) {
        final json = Map<String, Object?>.from(value as Map);
        return json['imageUrl'] as String;
      },
    );
  }

  @override
  Future<String> uploadProfileImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    return _apiClient.postMultipartBytes<String>(
      '/api/v1/users/me/profile-image',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
      decode: (value) {
        final json = Map<String, Object?>.from(value as Map);
        return json['imageUrl'] as String;
      },
    );
  }
}

class MemorySellerIdentityRepository implements SellerIdentityRepository {
  MemorySellerIdentityRepository({
    SellerIdentity identity = const SellerIdentity(
      userId: 1,
      email: 'seller@popq.test',
      name: 'POPQ 판매자',
      role: 'SELLER',
    ),
  }) : _identity = identity;

  SellerIdentity _identity;

  @override
  Future<SellerIdentity> getCurrent() async => _identity;

  @override
  Future<String> uploadProfileImage(String filePath) async {
    final imageUrl = Uri.file(filePath).toString();
    _identity = _identity.copyWith(profileImageUrl: imageUrl);
    return imageUrl;
  }

  @override
  Future<String> uploadProfileImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final imageUrl = 'memory://profile-images/$fileName';
    _identity = _identity.copyWith(profileImageUrl: imageUrl);
    return imageUrl;
  }
}

String? _resolveImageUrl(String? value, String? baseUrl) {
  final String path = value?.trim() ?? '';
  if (path.isEmpty) {
    return null;
  }

  final Uri? uri = Uri.tryParse(path);
  if (uri?.hasScheme == true) {
    return path;
  }

  final String base = baseUrl?.trim().replaceFirst(RegExp(r'/$'), '') ?? '';
  if (base.isEmpty) {
    return path;
  }

  return path.startsWith('/') ? '$base$path' : '$base/$path';
}
