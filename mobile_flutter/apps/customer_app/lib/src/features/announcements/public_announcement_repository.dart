import 'package:popq_app_core/popq_app_core.dart';

class PublicAnnouncement {
  const PublicAnnouncement({
    required this.announcementId,
    required this.storeId,
    required this.title,
    required this.content,
    required this.publishedAt,
    this.pinned = false,
  });

  factory PublicAnnouncement.fromJson(Map<String, Object?> json) {
    return PublicAnnouncement(
      announcementId: (json['announcementId'] as num).toInt(),
      storeId: (json['storeId'] as num).toInt(),
      title: json['title'] as String,
      content: json['content'] as String,
      pinned: json['pinned'] as bool? ?? false,
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
    );
  }

  final int announcementId;
  final int storeId;
  final String title;
  final String content;
  final bool pinned;
  final DateTime? publishedAt;
}

abstract interface class PublicAnnouncementRepository {
  Future<List<PublicAnnouncement>> findAll(int storeId);

  Future<PublicAnnouncement> findOne(int storeId, int announcementId);
}

class ApiPublicAnnouncementRepository implements PublicAnnouncementRepository {
  ApiPublicAnnouncementRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<List<PublicAnnouncement>> findAll(int storeId) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId/announcements',
      decode: (Object? value) => (value as List<Object?>)
          .map(
            (Object? item) => PublicAnnouncement.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<PublicAnnouncement> findOne(int storeId, int announcementId) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId/announcements/$announcementId',
      decode: (Object? value) =>
          PublicAnnouncement.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemoryPublicAnnouncementRepository
    implements PublicAnnouncementRepository {
  const MemoryPublicAnnouncementRepository({this.items = const []});

  final List<PublicAnnouncement> items;

  @override
  Future<List<PublicAnnouncement>> findAll(int storeId) async {
    final result = items
        .where((PublicAnnouncement item) => item.storeId == storeId)
        .toList();
    result.sort((left, right) {
      if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
      final leftPublished = left.publishedAt;
      final rightPublished = right.publishedAt;
      if (leftPublished == null) return rightPublished == null ? 0 : 1;
      if (rightPublished == null) return -1;
      return rightPublished.compareTo(leftPublished);
    });
    return List<PublicAnnouncement>.unmodifiable(result);
  }

  @override
  Future<PublicAnnouncement> findOne(int storeId, int announcementId) async {
    return items.firstWhere(
      (PublicAnnouncement item) =>
          item.storeId == storeId && item.announcementId == announcementId,
    );
  }
}
