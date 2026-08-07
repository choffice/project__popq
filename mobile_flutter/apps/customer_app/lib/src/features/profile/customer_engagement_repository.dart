import 'package:popq_app_core/popq_app_core.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.email,
    required this.name,
    required this.interestCount,
    required this.reviewCount,
    required this.orderCount,
  });

  factory CustomerProfile.fromJson(Map<String, Object?> json) {
    final user = Map<String, Object?>.from(json['user'] as Map);
    return CustomerProfile(
      userId: (user['userId'] as num).toInt(),
      email: user['email'] as String,
      name: user['name'] as String,
      interestCount: (json['interestCount'] as num).toInt(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      orderCount: (json['orderCount'] as num).toInt(),
    );
  }

  final int userId;
  final String email;
  final String name;
  final int interestCount;
  final int reviewCount;
  final int orderCount;

  CustomerProfile copyWith({
    int? interestCount,
    int? reviewCount,
    int? orderCount,
  }) {
    return CustomerProfile(
      userId: userId,
      email: email,
      name: name,
      interestCount: interestCount ?? this.interestCount,
      reviewCount: reviewCount ?? this.reviewCount,
      orderCount: orderCount ?? this.orderCount,
    );
  }
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
    this.sellerReply,
    this.sellerRepliedAt,
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
      sellerReply: json['sellerReply'] as String?,
      sellerRepliedAt: json['sellerRepliedAt'] is String
          ? DateTime.tryParse(json['sellerRepliedAt'] as String)
          : null,
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
  final String? sellerReply;
  final DateTime? sellerRepliedAt;

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
      sellerReply: sellerReply,
      sellerRepliedAt: sellerRepliedAt,
    );
  }
}

abstract interface class CustomerEngagementRepository {
  Future<CustomerProfile> getProfile();

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
      decode: (value) =>
          CustomerProfile.fromJson(Map<String, Object?>.from(value as Map)),
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

  @override
  Future<CustomerProfile> getProfile() async {
    _profile = _profile.copyWith(
      interestCount: _interests.length,
      reviewCount: _reviews.where((review) => review.isActive).length,
    );
    return _profile;
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
