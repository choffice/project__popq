import 'package:popq_app_core/popq_app_core.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.email,
    required this.name,
    required this.interestCount,
    required this.reviewCount,
    required this.orderCount,
    this.profileImageUrl,
    this.phone,
    this.joinedAt,
  });

  factory CustomerProfile.fromJson(
    Map<String, Object?> json, {
    String? imageBaseUrl,
  }) {
    final user = Map<String, Object?>.from(json['user'] as Map);
    return CustomerProfile(
      userId: (user['userId'] as num).toInt(),
      email: user['email'] as String,
      name: user['name'] as String,
      interestCount: (json['interestCount'] as num).toInt(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      orderCount: (json['orderCount'] as num).toInt(),
      profileImageUrl: _resolveImageUrl(
        user['profileImageUrl'] as String?,
        imageBaseUrl,
      ),
      phone: user['phone'] as String?,
      joinedAt: user['joinedAt'] == null
          ? null
          : DateTime.parse(user['joinedAt'] as String),
    );
  }

  final int userId;
  final String email;
  final String name;
  final int interestCount;
  final int reviewCount;
  final int orderCount;
  final String? profileImageUrl;
  final String? phone;
  final DateTime? joinedAt;

  /// 가입한 날을 1일째로 세어, 오늘까지 팝큐와 함께한 일수를 계산합니다.
  int? get daysSinceJoined {
    final joined = joinedAt;
    if (joined == null) return null;

    final today = DateTime.now();
    final joinedDate = DateTime(joined.year, joined.month, joined.day);
    final todayDate = DateTime(today.year, today.month, today.day);

    return todayDate.difference(joinedDate).inDays + 1;
  }

  CustomerProfile copyWith({
    String? name,
    int? interestCount,
    int? reviewCount,
    int? orderCount,
    String? profileImageUrl,
    String? phone,
  }) {
    return CustomerProfile(
      userId: userId,
      email: email,
      name: name ?? this.name,
      interestCount: interestCount ?? this.interestCount,
      reviewCount: reviewCount ?? this.reviewCount,
      orderCount: orderCount ?? this.orderCount,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phone: phone ?? this.phone,
      joinedAt: joinedAt,
    );
  }
}

class NotificationPreference {
  const NotificationPreference({
    required this.pushNotificationEnabled,
    required this.marketingOptIn,
  });

  factory NotificationPreference.fromJson(Map<String, Object?> json) {
    return NotificationPreference(
      pushNotificationEnabled: json['pushNotificationEnabled'] as bool,
      marketingOptIn: json['marketingOptIn'] as bool,
    );
  }

  final bool pushNotificationEnabled;
  final bool marketingOptIn;
}

class VisitedStore {
  const VisitedStore({
    required this.storeId,
    required this.storeName,
    required this.lastVisitedAt,
    this.storeCategory,
    this.storeImageUrl,
  });

  factory VisitedStore.fromJson(
    Map<String, Object?> json, {
    String? imageBaseUrl,
  }) {
    return VisitedStore(
      storeId: (json['storeId'] as num).toInt(),
      storeName: json['storeName'] as String,
      storeCategory: json['storeCategory'] as String?,
      storeImageUrl: _resolveImageUrl(
        json['storeImageUrl'] as String?,
        imageBaseUrl,
      ),
      lastVisitedAt: DateTime.parse(json['lastVisitedAt'] as String),
    );
  }

  final int storeId;
  final String storeName;
  final String? storeCategory;
  final String? storeImageUrl;
  final DateTime lastVisitedAt;
}

class InterestedStore {
  const InterestedStore({
    required this.storeId,
    required this.name,
    required this.businessStatus,
    this.storeType = 'LOCAL_STORE',
    this.description,
    this.address,
    this.detailAddress,
    this.representativeCategory,
    this.imageUrl,
  });

  factory InterestedStore.fromJson(
    Map<String, Object?> json, {
    String? imageBaseUrl,
  }) {
    return InterestedStore(
      storeId: (json['storeId'] as num).toInt(),
      storeType: json['storeType'] as String? ?? 'LOCAL_STORE',
      name: json['name'] as String,
      businessStatus: json['businessStatus'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      detailAddress: json['detailAddress'] as String?,
      representativeCategory: json['representativeCategory'] as String?,
      imageUrl: _resolveImageUrl(
        json['imageUrl'] as String?,
        imageBaseUrl,
      ),
    );
  }

  final int storeId;
  final String storeType;
  final String name;
  final String businessStatus;
  final String? description;
  final String? address;
  final String? detailAddress;
  final String? representativeCategory;
  final String? imageUrl;

  String get fullAddress {
    return <String?>[address, detailAddress]
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' ');
  }
}

class CustomerReview {
  const CustomerReview({
    required this.reviewId,
    required this.orderPublicId,
    required this.storeId,
    required this.storeName,
    required this.authorName,
    required this.rating,
    required this.status,
    required this.createdAt,
    this.content,
    this.storeCategory,
  });

  factory CustomerReview.fromJson(Map<String, Object?> json) {
    return CustomerReview(
      reviewId: (json['reviewId'] as num).toInt(),
      orderPublicId: json['orderPublicId'] as String,
      storeId: (json['storeId'] as num).toInt(),
      storeName: json['storeName'] as String,
      storeCategory: json['storeCategory'] as String?,
      authorName: json['authorName'] as String,
      rating: (json['rating'] as num).toInt(),
      content: json['content'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int reviewId;
  final String orderPublicId;
  final int storeId;
  final String storeName;
  final String? storeCategory;
  final String authorName;
  final int rating;
  final String? content;
  final String status;
  final DateTime createdAt;

  bool get isActive => status == 'ACTIVE';

  CustomerReview copyWith({int? rating, String? content, String? status}) {
    return CustomerReview(
      reviewId: reviewId,
      orderPublicId: orderPublicId,
      storeId: storeId,
      storeName: storeName,
      storeCategory: storeCategory,
      authorName: authorName,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

abstract interface class CustomerEngagementRepository {
  Future<CustomerProfile> getProfile();

  Future<String> uploadProfileImage(String filePath);

  Future<bool> updateName(String name);

  Future<bool> updatePhone(String phone);

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<NotificationPreference> getNotificationPreferences();

  Future<NotificationPreference> updateNotificationPreferences({
    required bool pushNotificationEnabled,
    required bool marketingOptIn,
  });

  Future<List<String>> getLinkedSocialProviders();

  Future<List<VisitedStore>> findVisitedStores();

  Future<List<InterestedStore>> findInterests();

  Future<bool> isInterested(int storeId);

  Future<bool> addInterest(int storeId);

  Future<bool> removeInterest(int storeId);

  Future<List<CustomerReview>> findMyReviews();

  Future<List<CustomerReview>> findPublicReviews(int storeId);

  Future<CustomerReview> createReview({
    required String orderPublicId,
    required int rating,
    required String content,
  });

  Future<CustomerReview> updateReview({
    required int reviewId,
    required int rating,
    required String content,
  });

  Future<CustomerReview> deleteReview(int reviewId);
}

class ApiCustomerEngagementRepository implements CustomerEngagementRepository {
  ApiCustomerEngagementRepository(
    this._apiClient, {
    required this._imageBaseUrl,
  });

  final PopqApiClient _apiClient;
  final String _imageBaseUrl;

  @override
  Future<CustomerProfile> getProfile() {
    return _apiClient.get(
      '/api/v1/customer/profile',
      decode: (value) => CustomerProfile.fromJson(
        Map<String, Object?>.from(value as Map),
        imageBaseUrl: _imageBaseUrl,
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
  Future<bool> updateName(String name) {
    return _apiClient.patch<bool>(
      '/api/v1/users/me/name',
      body: {'name': name},
      decode: _decodeAck,
    );
  }

  @override
  Future<bool> updatePhone(String phone) {
    return _apiClient.patch<bool>(
      '/api/v1/users/me/phone',
      body: {'phone': phone},
      decode: _decodeAck,
    );
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _apiClient.post<bool>(
      '/api/v1/users/me/password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      decode: _decodeAck,
    );
  }

  @override
  Future<NotificationPreference> getNotificationPreferences() {
    return _apiClient.get(
      '/api/v1/users/me/notification-preferences',
      decode: (value) => NotificationPreference.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<NotificationPreference> updateNotificationPreferences({
    required bool pushNotificationEnabled,
    required bool marketingOptIn,
  }) {
    return _apiClient.patch(
      '/api/v1/users/me/notification-preferences',
      body: {
        'pushNotificationEnabled': pushNotificationEnabled,
        'marketingOptIn': marketingOptIn,
      },
      decode: (value) => NotificationPreference.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<List<String>> getLinkedSocialProviders() {
    return _apiClient.get(
      '/api/v1/users/me/social-accounts',
      decode: (value) {
        final json = Map<String, Object?>.from(value as Map);
        return (json['providers'] as List<Object?>)
            .map((item) => item as String)
            .toList();
      },
    );
  }

  bool _decodeAck(Object? value) {
    final json = Map<String, Object?>.from(value as Map);
    return json['success'] as bool;
  }

  @override
  Future<List<VisitedStore>> findVisitedStores() {
    return _apiClient.get(
      '/api/v1/customer/visited-stores',
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => VisitedStore.fromJson(
              Map<String, Object?>.from(item as Map),
              imageBaseUrl: _imageBaseUrl,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<InterestedStore>> findInterests() {
    return _apiClient.get(
      '/api/v1/customer/store-interests',
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => InterestedStore.fromJson(
              Map<String, Object?>.from(item as Map),
              imageBaseUrl: _imageBaseUrl,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<bool> isInterested(int storeId) {
    return _apiClient.get(
      '/api/v1/customer/store-interests/$storeId',
      decode: _decodeInterest,
    );
  }

  @override
  Future<bool> addInterest(int storeId) {
    return _apiClient.post(
      '/api/v1/customer/store-interests/$storeId',
      decode: _decodeInterest,
    );
  }

  @override
  Future<bool> removeInterest(int storeId) {
    return _apiClient.delete(
      '/api/v1/customer/store-interests/$storeId',
      decode: _decodeInterest,
    );
  }

  @override
  Future<List<CustomerReview>> findMyReviews() {
    return _apiClient.get('/api/v1/customer/reviews', decode: _decodeReviews);
  }

  @override
  Future<List<CustomerReview>> findPublicReviews(int storeId) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId/reviews',
      decode: _decodeReviews,
    );
  }

  @override
  Future<CustomerReview> createReview({
    required String orderPublicId,
    required int rating,
    required String content,
  }) {
    return _apiClient.post(
      '/api/v1/customer/reviews/orders/$orderPublicId',
      body: {'rating': rating, 'content': content},
      decode: _decodeReview,
    );
  }

  @override
  Future<CustomerReview> updateReview({
    required int reviewId,
    required int rating,
    required String content,
  }) {
    return _apiClient.put(
      '/api/v1/customer/reviews/$reviewId',
      body: {'rating': rating, 'content': content},
      decode: _decodeReview,
    );
  }

  @override
  Future<CustomerReview> deleteReview(int reviewId) {
    return _apiClient.delete(
      '/api/v1/customer/reviews/$reviewId',
      decode: _decodeReview,
    );
  }

  bool _decodeInterest(Object? value) {
    final json = Map<String, Object?>.from(value as Map);
    return json['interested'] as bool;
  }

  CustomerReview _decodeReview(Object? value) {
    return CustomerReview.fromJson(Map<String, Object?>.from(value as Map));
  }

  List<CustomerReview> _decodeReviews(Object? value) {
    return (value as List<Object?>)
        .map(
          (item) =>
              CustomerReview.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
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

class MemoryCustomerEngagementRepository
    implements CustomerEngagementRepository {
  MemoryCustomerEngagementRepository({
    CustomerProfile? profile,
    List<InterestedStore> interests = const [],
    List<CustomerReview> reviews = const [],
  }) : _profile =
           profile ??
           const CustomerProfile(
             userId: 1,
             email: 'customer@popq.test',
             name: 'POPQ 고객',
             interestCount: 0,
             reviewCount: 0,
             orderCount: 0,
           ),
       _interests = List.of(interests),
       _reviews = List.of(reviews);

  CustomerProfile _profile;
  final List<InterestedStore> _interests;
  final List<CustomerReview> _reviews;
  NotificationPreference _notificationPreference = const NotificationPreference(
    pushNotificationEnabled: true,
    marketingOptIn: false,
  );

  @override
  Future<CustomerProfile> getProfile() async {
    _profile = _profile.copyWith(
      interestCount: _interests.length,
      reviewCount: _reviews.where((review) => review.isActive).length,
    );
    return _profile;
  }

  @override
  Future<String> uploadProfileImage(String filePath) async {
    final imageUrl = Uri.file(filePath).toString();
    _profile = _profile.copyWith(profileImageUrl: imageUrl);
    return imageUrl;
  }

  @override
  Future<bool> updateName(String name) async {
    _profile = _profile.copyWith(name: name);
    return true;
  }

  @override
  Future<bool> updatePhone(String phone) async {
    _profile = _profile.copyWith(phone: phone);
    return true;
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return true;
  }

  @override
  Future<NotificationPreference> getNotificationPreferences() async {
    return _notificationPreference;
  }

  @override
  Future<NotificationPreference> updateNotificationPreferences({
    required bool pushNotificationEnabled,
    required bool marketingOptIn,
  }) async {
    _notificationPreference = NotificationPreference(
      pushNotificationEnabled: pushNotificationEnabled,
      marketingOptIn: marketingOptIn,
    );
    return _notificationPreference;
  }

  @override
  Future<List<String>> getLinkedSocialProviders() async {
    return const [];
  }

  @override
  Future<List<VisitedStore>> findVisitedStores() async {
    return const [];
  }

  @override
  Future<List<InterestedStore>> findInterests() async {
    return List.unmodifiable(_interests);
  }

  @override
  Future<bool> isInterested(int storeId) async {
    return _interests.any((store) => store.storeId == storeId);
  }

  @override
  Future<bool> addInterest(int storeId) async {
    if (!await isInterested(storeId)) {
      _interests.insert(
        0,
        InterestedStore(
          storeId: storeId,
          name: '관심 스토어 $storeId',
          businessStatus: 'OPEN',
        ),
      );
    }
    return true;
  }

  @override
  Future<bool> removeInterest(int storeId) async {
    _interests.removeWhere((store) => store.storeId == storeId);
    return false;
  }

  @override
  Future<List<CustomerReview>> findMyReviews() async {
    return List.unmodifiable(_reviews);
  }

  @override
  Future<List<CustomerReview>> findPublicReviews(int storeId) async {
    return _reviews
        .where((review) => review.storeId == storeId && review.isActive)
        .toList();
  }

  @override
  Future<CustomerReview> createReview({
    required String orderPublicId,
    required int rating,
    required String content,
  }) async {
    final review = CustomerReview(
      reviewId: _reviews.length + 1,
      orderPublicId: orderPublicId,
      storeId: 1,
      storeName: 'POPQ 스토어',
      authorName: _profile.name,
      rating: rating,
      content: content,
      status: 'ACTIVE',
      createdAt: DateTime.now(),
    );
    _reviews.insert(0, review);
    return review;
  }

  @override
  Future<CustomerReview> updateReview({
    required int reviewId,
    required int rating,
    required String content,
  }) async {
    final index = _reviews.indexWhere((review) => review.reviewId == reviewId);
    final updated = _reviews[index].copyWith(rating: rating, content: content);
    _reviews[index] = updated;
    return updated;
  }

  @override
  Future<CustomerReview> deleteReview(int reviewId) async {
    final index = _reviews.indexWhere((review) => review.reviewId == reviewId);
    final deleted = _reviews[index].copyWith(content: '', status: 'DELETED');
    _reviews[index] = deleted;
    return deleted;
  }
}
