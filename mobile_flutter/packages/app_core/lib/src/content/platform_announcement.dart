import '../network/popq_api_client.dart';

enum PlatformAnnouncementAudience {
  customerApp('CUSTOMER_APP'),
  sellerApp('SELLER_APP');

  const PlatformAnnouncementAudience(this.apiValue);

  final String apiValue;
}

class PlatformAnnouncement {
  const PlatformAnnouncement({
    required this.platformAnnouncementId,
    required this.audience,
    required this.title,
    required this.content,
    required this.status,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
    this.publishStartAt,
    this.publishEndAt,
  });

  factory PlatformAnnouncement.fromJson(Map<String, Object?> json) {
    return PlatformAnnouncement(
      platformAnnouncementId: (json['platformAnnouncementId'] as num).toInt(),
      audience: json['audience'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      publishStartAt: _parseDateTime(json['publishStartAt']),
      publishEndAt: _parseDateTime(json['publishEndAt']),
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final int platformAnnouncementId;
  final String audience;
  final String title;
  final String content;
  final String status;
  final DateTime? publishStartAt;
  final DateTime? publishEndAt;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get displayDate => publishStartAt ?? createdAt;

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

abstract interface class PlatformAnnouncementRepository {
  Future<List<PlatformAnnouncement>> findAll();

  Future<PlatformAnnouncement> findOne(int platformAnnouncementId);
}

class ApiPlatformAnnouncementRepository
    implements PlatformAnnouncementRepository {
  ApiPlatformAnnouncementRepository(
    this._apiClient, {
    required PlatformAnnouncementAudience audience,
  }) : _audience = audience;

  final PopqApiClient _apiClient;
  final PlatformAnnouncementAudience _audience;

  static const String _basePath = '/api/v1/public/content/announcements';

  @override
  Future<List<PlatformAnnouncement>> findAll() {
    return _apiClient.get(
      _basePath,
      query: <String, Object?>{'audience': _audience.apiValue},
      decode: (Object? value) => (value as List<Object?>)
          .map(
            (Object? item) => PlatformAnnouncement.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<PlatformAnnouncement> findOne(int platformAnnouncementId) {
    if (platformAnnouncementId <= 0) {
      throw ArgumentError.value(
        platformAnnouncementId,
        'platformAnnouncementId',
        '공지사항 ID는 1 이상이어야 합니다.',
      );
    }

    return _apiClient.get(
      '$_basePath/$platformAnnouncementId',
      query: <String, Object?>{'audience': _audience.apiValue},
      decode: (Object? value) => PlatformAnnouncement.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }
}

class MemoryPlatformAnnouncementRepository
    implements PlatformAnnouncementRepository {
  const MemoryPlatformAnnouncementRepository({this.items = const []});

  final List<PlatformAnnouncement> items;

  @override
  Future<List<PlatformAnnouncement>> findAll() async {
    final result = List<PlatformAnnouncement>.of(items)
      ..sort(
        (PlatformAnnouncement left, PlatformAnnouncement right) =>
            right.displayDate.compareTo(left.displayDate),
      );
    return List<PlatformAnnouncement>.unmodifiable(result);
  }

  @override
  Future<PlatformAnnouncement> findOne(int platformAnnouncementId) async {
    return items.firstWhere(
      (PlatformAnnouncement item) =>
          item.platformAnnouncementId == platformAnnouncementId,
    );
  }
}
