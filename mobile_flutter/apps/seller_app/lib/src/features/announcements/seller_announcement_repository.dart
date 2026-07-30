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
    this.publishedAt,
  });

  factory SellerAnnouncement.fromJson(Map<String, Object?> json) {
    return SellerAnnouncement(
      announcementId: (json['announcementId'] as num).toInt(),
      storeId: (json['storeId'] as num).toInt(),
      title: json['title'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.parse(json['publishedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final int announcementId;
  final int storeId;
  final String title;
  final String content;
  final String status;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  SellerAnnouncement copyWith({
    String? title,
    String? content,
    String? status,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return SellerAnnouncement(
      announcementId: announcementId,
      storeId: storeId,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract interface class SellerAnnouncementRepository {
  Future<List<SellerAnnouncement>> findAll(int storeId);

  Future<SellerAnnouncement> create(
    int storeId, {
    required String title,
    required String content,
  });

  Future<SellerAnnouncement> update(
    int storeId,
    SellerAnnouncement announcement, {
    required String title,
    required String content,
  });

  Future<SellerAnnouncement> changeStatus(
    int storeId,
    SellerAnnouncement announcement,
    String status,
  );
}

class ApiSellerAnnouncementRepository
    implements SellerAnnouncementRepository {
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
  }) {
    return _apiClient.post(
      _basePath(storeId),
      body: {'title': title, 'content': content},
      decode: (value) => SellerAnnouncement.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerAnnouncement> update(
    int storeId,
    SellerAnnouncement announcement, {
    required String title,
    required String content,
  }) {
    _requireStore(storeId, announcement);
    return _apiClient.patch(
      '${_basePath(storeId)}/${announcement.announcementId}',
      body: {'title': title, 'content': content},
      decode: (value) => SellerAnnouncement.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
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
      decode: (value) => SellerAnnouncement.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
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
    final result = _announcements
        .where((item) => item.storeId == storeId)
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List.unmodifiable(result);
  }

  @override
  Future<SellerAnnouncement> create(
    int storeId, {
    required String title,
    required String content,
  }) async {
    final now = DateTime.now().toUtc();
    final nextId = _announcements.fold<int>(
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
      status: 'DRAFT',
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
  }) async {
    final index = _findIndex(storeId, announcement);
    final updated = announcement.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now().toUtc(),
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
      publishedAt: status == 'PUBLISHED' ? now : announcement.publishedAt,
      updatedAt: now,
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

