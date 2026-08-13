import 'dart:typed_data';

import 'package:popq_app_core/popq_app_core.dart';

class SellerAnnouncement {
  const SellerAnnouncement({
    required this.announcementId,
    required this.storeId,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.pinned = false,
    this.publishedAt,
  });

  factory SellerAnnouncement.fromJson(Map<String, Object?> json) {
    return SellerAnnouncement(
      announcementId: (json['announcementId'] as num).toInt(),
      storeId: (json['storeId'] as num).toInt(),
      title: json['title'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      pinned: json['pinned'] as bool? ?? false,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.parse(json['publishedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final int announcementId;
  final int storeId;
  final String title;
  final String content;
  final String status;
  final bool pinned;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;

  SellerAnnouncement copyWith({
    String? title,
    String? content,
    String? status,
    bool? pinned,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return SellerAnnouncement(
      announcementId: announcementId,
      storeId: storeId,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      pinned: pinned ?? this.pinned,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: this.imageUrl,
    );
  }
}

abstract interface class SellerAnnouncementRepository {
  Future<List<SellerAnnouncement>> findAll(int storeId);

  Future<String> uploadAnnouncementImage(
    String filePath,
  );

  Future<String> uploadAnnouncementImageBytes(
    Uint8List bytes, {
    required String fileName,
  });

  Future<SellerAnnouncement> create(
    int storeId, {
    required String title,
    required String content,
    String? imageUrl,
    required bool notifyInterestedCustomers,
  });

  Future<SellerAnnouncement> update(
    int storeId,
    SellerAnnouncement announcement, {
    required String title,
    required String content,
    String? imageUrl,
    required bool notifyInterestedCustomers,
  });

  Future<SellerAnnouncement> changeStatus(
    int storeId,
    SellerAnnouncement announcement,
    String status,
  );

  Future<SellerAnnouncement> changePin(
    int storeId,
    SellerAnnouncement announcement,
    bool pinned,
  );
}

class ApiSellerAnnouncementRepository implements SellerAnnouncementRepository {
  ApiSellerAnnouncementRepository(this._apiClient);

  final PopqApiClient _apiClient;

  String _basePath(int storeId) =>
      '/api/v1/seller/stores/$storeId/announcements';

  @override
  Future<List<SellerAnnouncement>> findAll(int storeId) {
    return _apiClient.get(
      _basePath(storeId),
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => SellerAnnouncement.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SellerAnnouncement> create(
    int storeId, {
    required String title,
    required String content,
    required bool notifyInterestedCustomers,
    String? imageUrl,
  }) {
    return _apiClient.post(
      _basePath(storeId),
      body: {
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'notifyInterestedCustomers': notifyInterestedCustomers,
      },
      decode: (value) =>
          SellerAnnouncement.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerAnnouncement> update(
    int storeId,
    SellerAnnouncement announcement, {
    required String title,
    required String content,
    required bool notifyInterestedCustomers,
    String? imageUrl,
  }) {
    _requireStore(storeId, announcement);
    return _apiClient.patch(
      '${_basePath(storeId)}/${announcement.announcementId}',
      body: {
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'notifyInterestedCustomers': notifyInterestedCustomers,
      },
      decode: (value) =>
          SellerAnnouncement.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerAnnouncement> changeStatus(
    int storeId,
    SellerAnnouncement announcement,
    String status,
  ) {
    _requireStore(storeId, announcement);
    return _apiClient.patch(
      '${_basePath(storeId)}/${announcement.announcementId}/status',
      body: {'status': status},
      decode: (value) =>
          SellerAnnouncement.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerAnnouncement> changePin(
    int storeId,
    SellerAnnouncement announcement,
    bool pinned,
  ) {
    _requireStore(storeId, announcement);
    return _apiClient.patch(
      '${_basePath(storeId)}/${announcement.announcementId}/pin',
      body: {'pinned': pinned},
      decode: (value) =>
          SellerAnnouncement.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<String> uploadAnnouncementImage(
    String filePath,
  ) {
    return _apiClient.postMultipartFile<String>(
      '/api/v1/seller/store-images',
      fieldName: 'file',
      filePath: filePath,
      decode: (Object? value) {
        final json = Map<String, Object?>.from(value as Map);
        final imageUrl = json['imageUrl'];
        if (imageUrl is! String || imageUrl.trim().isEmpty) {
          throw const InvalidResponseFailure('업로드된 이미지 URL이 없습니다.');
        }
        return imageUrl;
      },
    );
  }

  @override
  Future<String> uploadAnnouncementImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    return _apiClient.postMultipartBytes<String>(
      '/api/v1/seller/store-images',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
      decode: (Object? value) {
        final json = Map<String, Object?>.from(value as Map);

        final imageUrl = json['imageUrl'];

        if (imageUrl is! String || imageUrl.trim().isEmpty) {
          throw const InvalidResponseFailure('업로드된 이미지 URL이 없습니다.');
        }

        return imageUrl;
      },
    );
  }

  void _requireStore(int storeId, SellerAnnouncement announcement) {
    if (announcement.storeId != storeId) {
      throw StateError('announcement does not belong to selected store');
    }
  }
}

class MemorySellerAnnouncementRepository
    implements SellerAnnouncementRepository {
  MemorySellerAnnouncementRepository({
    List<SellerAnnouncement> announcements = const [],
  }) : _announcements = List.of(announcements);

  final List<SellerAnnouncement> _announcements;

  @override
  Future<List<SellerAnnouncement>> findAll(int storeId) async {
    final result =
        _announcements.where((item) => item.storeId == storeId).toList()
          ..sort(_compareAnnouncements);
    return List.unmodifiable(result);
  }

  @override
  Future<String> uploadAnnouncementImage(
    String filePath,
  ) async {
    return filePath;
  }

  @override
  Future<String> uploadAnnouncementImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    return 'memory://announcement-images/$fileName';
  }

  @override
  Future<SellerAnnouncement> create(
    int storeId, {
    required String title,
    required String content,
    required bool notifyInterestedCustomers,
    String? imageUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final nextId =
        _announcements.fold<int>(
          0,
          (value, item) =>
              item.announcementId > value ? item.announcementId : value,
        ) +
        1;
    final created = SellerAnnouncement(
      announcementId: nextId,
      storeId: storeId,
      title: title,
      content: content,
      imageUrl: imageUrl,
      status: notifyInterestedCustomers ? 'PUBLISHED' : 'DRAFT',
      pinned: false,
      publishedAt: notifyInterestedCustomers ? now : null,
      createdAt: now,
      updatedAt: now,
    );
    _announcements.add(created);
    return created;
  }

  @override
  Future<SellerAnnouncement> update(
    int storeId,
    SellerAnnouncement announcement, {
    required String title,
    required String content,
    required bool notifyInterestedCustomers,
    String? imageUrl,
  }) async {
    final index = _findIndex(storeId, announcement);
    final now = DateTime.now().toUtc();

    final updated = SellerAnnouncement(
      announcementId: announcement.announcementId,
      storeId: announcement.storeId,
      title: title,
      content: content,
      imageUrl: imageUrl,
      status: notifyInterestedCustomers ? 'PUBLISHED' : announcement.status,
      pinned: announcement.pinned,
      publishedAt: notifyInterestedCustomers ? now : announcement.publishedAt,
      createdAt: announcement.createdAt,
      updatedAt: now,
    );
    _announcements[index] = updated;
    return updated;
  }

  @override
  Future<SellerAnnouncement> changeStatus(
    int storeId,
    SellerAnnouncement announcement,
    String status,
  ) async {
    final index = _findIndex(storeId, announcement);
    final now = DateTime.now().toUtc();
    final updated = announcement.copyWith(
      status: status,
      pinned: status == 'PUBLISHED' ? announcement.pinned : false,
      publishedAt: status == 'PUBLISHED' ? now : announcement.publishedAt,
      updatedAt: now,
    );
    _announcements[index] = updated;
    return updated;
  }

  @override
  Future<SellerAnnouncement> changePin(
    int storeId,
    SellerAnnouncement announcement,
    bool pinned,
  ) async {
    final index = _findIndex(storeId, announcement);
    if (pinned && announcement.status != 'PUBLISHED') {
      throw StateError('only published announcements can be pinned');
    }
    if (pinned && !announcement.pinned) {
      final pinnedCount = _announcements
          .where((item) => item.storeId == storeId && item.pinned)
          .length;
      if (pinnedCount >= 3) {
        throw StateError('announcement pin limit exceeded');
      }
    }
    final updated = announcement.copyWith(
      pinned: pinned,
      updatedAt: DateTime.now().toUtc(),
    );
    _announcements[index] = updated;
    return updated;
  }

  int _findIndex(int storeId, SellerAnnouncement announcement) {
    final index = _announcements.indexWhere(
      (item) =>
          item.storeId == storeId &&
          item.announcementId == announcement.announcementId,
    );
    if (index < 0 || announcement.storeId != storeId) {
      throw StateError('announcement not found in selected store');
    }
    return index;
  }
}

int _compareAnnouncements(SellerAnnouncement left, SellerAnnouncement right) {
  if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
  if (left.pinned) {
    final publishedOrder = (right.publishedAt ?? right.createdAt).compareTo(
      left.publishedAt ?? left.createdAt,
    );
    if (publishedOrder != 0) return publishedOrder;
  }
  final createdOrder = right.createdAt.compareTo(left.createdAt);
  if (createdOrder != 0) return createdOrder;
  return right.announcementId.compareTo(left.announcementId);
}
