import 'package:popq_app_core/popq_app_core.dart';

String sellerReviewEmblemLabel(String badgeTier) {
  return switch (badgeTier) {
    'BRONZE' => '브론즈',
    'SILVER' => '실버',
    'GOLD' => '골드',
    'DIAMOND' => '다이아',
    _ => '',
  };
}

String? sellerReviewEmblemAssetPath(String badgeTier) {
  return switch (badgeTier) {
    'BRONZE' => 'assets/images/badges/badge_bronze.png',
    'SILVER' => 'assets/images/badges/badge_silver.png',
    'GOLD' => 'assets/images/badges/badge_gold.png',
    'DIAMOND' => 'assets/images/badges/badge_diamond.png',
    _ => null,
  };
}

class SellerReviewReplyTemplate {
  const SellerReviewReplyTemplate({
    required this.templateId,
    required this.content,
  });

  factory SellerReviewReplyTemplate.fromJson(Map<String, Object?> json) {
    return SellerReviewReplyTemplate(
      templateId: (json['templateId'] as num).toInt(),
      content: json['content'] as String,
    );
  }

  final int templateId;
  final String content;
}

class SellerReview {
  const SellerReview({
    required this.reviewId,
    required this.orderPublicId,
    required this.storeId,
    required this.authorName,
    required this.rating,
    required this.createdAt,
    this.content,
    this.sellerReply,
    this.sellerRepliedAt,
    this.authorBadgeTier = 'NONE',
  });

  factory SellerReview.fromJson(Map<String, Object?> json) {
    return SellerReview(
      reviewId: (json['reviewId'] as num).toInt(),
      orderPublicId: json['orderPublicId'] as String,
      storeId: (json['storeId'] as num).toInt(),
      authorName: json['authorName'] as String,
      authorBadgeTier: json['authorBadgeTier'] as String? ?? 'NONE',
      rating: (json['rating'] as num).toInt(),
      content: json['content'] as String?,
      sellerReply: json['sellerReply'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sellerRepliedAt: json['sellerRepliedAt'] is String
          ? DateTime.tryParse(json['sellerRepliedAt'] as String)
          : null,
    );
  }

  final int reviewId;
  final String orderPublicId;
  final int storeId;
  final String authorName;
  final String authorBadgeTier;
  final int rating;
  final String? content;
  final DateTime createdAt;
  final String? sellerReply;
  final DateTime? sellerRepliedAt;
  String get authorEmblemLabel => sellerReviewEmblemLabel(authorBadgeTier);
  String? get authorEmblemAssetPath =>
      sellerReviewEmblemAssetPath(authorBadgeTier);

  SellerReview copyWith({String? sellerReply, bool clearReply = false}) {
    return SellerReview(
      reviewId: reviewId,
      orderPublicId: orderPublicId,
      storeId: storeId,
      authorName: authorName,
      authorBadgeTier: authorBadgeTier,
      rating: rating,
      content: content,
      createdAt: createdAt,
      sellerReply: clearReply ? null : sellerReply ?? this.sellerReply,
      sellerRepliedAt: clearReply ? null : DateTime.now().toUtc(),
    );
  }
}

abstract interface class SellerReviewRepository {
  Future<List<SellerReview>> findAll(
    int storeId, {
    int? rating,
    bool unanswered = false,
  });

  Future<SellerReview?> findByOrder(int storeId, String orderPublicId);

  Future<SellerReview> reply(int storeId, int reviewId, String reply);

  Future<SellerReview> deleteReply(int storeId, int reviewId);

  Future<List<SellerReviewReplyTemplate>> findReplyTemplates(int storeId);

  Future<SellerReviewReplyTemplate> createReplyTemplate(
    int storeId,
    String content,
  );

  Future<SellerReviewReplyTemplate> updateReplyTemplate(
    int storeId,
    int templateId,
    String content,
  );

  Future<void> deleteReplyTemplate(int storeId, int templateId);
}

class ApiSellerReviewRepository implements SellerReviewRepository {
  ApiSellerReviewRepository(this._apiClient);

  final PopqApiClient _apiClient;

  String _basePath(int storeId) => '/api/v1/seller/stores/$storeId/reviews';

  @override
  Future<List<SellerReview>> findAll(
    int storeId, {
    int? rating,
    bool unanswered = false,
  }) {
    return _apiClient.get(
      _basePath(storeId),
      query: {
        if (rating != null) 'rating': rating,
        if (unanswered) 'unanswered': true,
      },
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => SellerReview.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SellerReview?> findByOrder(int storeId, String orderPublicId) {
    return _apiClient.get(
      '${_basePath(storeId)}/orders/$orderPublicId',
      decode: (value) => value == null
          ? null
          : SellerReview.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerReview> reply(int storeId, int reviewId, String reply) {
    return _apiClient.put(
      '${_basePath(storeId)}/$reviewId/reply',
      body: {'reply': reply},
      decode: (value) => SellerReview.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerReview> deleteReply(int storeId, int reviewId) {
    return _apiClient.delete(
      '${_basePath(storeId)}/$reviewId/reply',
      decode: (value) => SellerReview.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<List<SellerReviewReplyTemplate>> findReplyTemplates(int storeId) {
    return _apiClient.get(
      '${_basePath(storeId)}/reply-templates',
      decode: (value) => (value as List<Object?>)
          .map(
            (item) => SellerReviewReplyTemplate.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SellerReviewReplyTemplate> createReplyTemplate(
    int storeId,
    String content,
  ) {
    return _apiClient.post(
      '${_basePath(storeId)}/reply-templates',
      body: {'content': content},
      decode: (value) => SellerReviewReplyTemplate.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerReviewReplyTemplate> updateReplyTemplate(
    int storeId,
    int templateId,
    String content,
  ) {
    return _apiClient.patch(
      '${_basePath(storeId)}/reply-templates/$templateId',
      body: {'content': content},
      decode: (value) => SellerReviewReplyTemplate.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<void> deleteReplyTemplate(int storeId, int templateId) async {
    await _apiClient.delete<Object?>(
      '${_basePath(storeId)}/reply-templates/$templateId',
      decode: (value) => value,
    );
  }
}

class MemorySellerReviewRepository implements SellerReviewRepository {
  MemorySellerReviewRepository({List<SellerReview> reviews = const []})
      : _reviews = List.of(reviews);

  final List<SellerReview> _reviews;
  final Map<int, List<SellerReviewReplyTemplate>> _templatesByStore = {};

  List<SellerReviewReplyTemplate> _templates(int storeId) =>
      _templatesByStore.putIfAbsent(storeId, () => []);

  @override
  Future<List<SellerReview>> findAll(
    int storeId, {
    int? rating,
    bool unanswered = false,
  }) async => _reviews
      .where((review) => review.storeId == storeId)
      .where((review) => rating == null || review.rating == rating)
      .where((review) => !unanswered || review.sellerReply == null)
      .toList();

  @override
  Future<SellerReview?> findByOrder(int storeId, String orderPublicId) async {
    for (final review in _reviews) {
      if (review.storeId == storeId && review.orderPublicId == orderPublicId) {
        return review;
      }
    }
    return null;
  }

  @override
  Future<SellerReview> reply(int storeId, int reviewId, String reply) async {
    final index = _reviews.indexWhere(
      (review) => review.storeId == storeId && review.reviewId == reviewId,
    );
    if (index < 0) throw StateError('review not found');
    return _reviews[index] = _reviews[index].copyWith(sellerReply: reply.trim());
  }

  @override
  Future<SellerReview> deleteReply(int storeId, int reviewId) async {
    final index = _reviews.indexWhere(
      (review) => review.storeId == storeId && review.reviewId == reviewId,
    );
    if (index < 0) throw StateError('review not found');
    return _reviews[index] = _reviews[index].copyWith(clearReply: true);
  }

  @override
  Future<List<SellerReviewReplyTemplate>> findReplyTemplates(int storeId) async {
    return List.unmodifiable(_templates(storeId));
  }

  @override
  Future<SellerReviewReplyTemplate> createReplyTemplate(
    int storeId,
    String content,
  ) async {
    final templates = _templates(storeId);
    final nextId = templates.isEmpty
        ? 1
        : templates
                .map((item) => item.templateId)
                .reduce((a, b) => a > b ? a : b) +
            1;
    final created = SellerReviewReplyTemplate(
      templateId: nextId,
      content: content.trim(),
    );
    templates.add(created);
    return created;
  }

  @override
  Future<SellerReviewReplyTemplate> updateReplyTemplate(
    int storeId,
    int templateId,
    String content,
  ) async {
    final templates = _templates(storeId);
    final index = templates.indexWhere((item) => item.templateId == templateId);
    if (index < 0) throw StateError('reply template not found');
    return templates[index] = SellerReviewReplyTemplate(
      templateId: templateId,
      content: content.trim(),
    );
  }

  @override
  Future<void> deleteReplyTemplate(int storeId, int templateId) async {
    _templates(storeId).removeWhere((item) => item.templateId == templateId);
  }
}
