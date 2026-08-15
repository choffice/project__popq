package com.example.project_popq.engagement.dto;

import com.example.project_popq.activity.domain.CustomerBadgeTier;
import com.example.project_popq.engagement.domain.Review;
import com.example.project_popq.engagement.domain.ReviewStatus;
import java.time.Instant;

public record ReviewResponse(
        Long reviewId,
        String orderPublicId,
        Long storeId,
        String storeName,
        String storeCategory,
        String authorName,
        CustomerBadgeTier authorBadgeTier,
        int rating,
        String content,
        String imageUrl,
        ReviewStatus status,
        Instant createdAt,
        Instant updatedAt,
        String sellerReply,
        Instant sellerRepliedAt,
        Long sellerRepliedByUserId
) {
    public static ReviewResponse from(
            Review review,
            CustomerBadgeTier authorBadgeTier
    ) {
        return new ReviewResponse(
                review.getId(),
                review.getOrder().getOrderPublicId(),
                review.getStore().getId(),
                review.getStore().getName(),
                review.getStore().getRepresentativeCategory(),
                review.getUser().getName(),
                authorBadgeTier,
                review.getRating(),
                review.getContent(),
                review.getImageUrl(),
                review.getStatus(),
                review.getCreatedAt(),
                review.getUpdatedAt(),
                review.getSellerReply(),
                review.getSellerRepliedAt(),
                review.getSellerRepliedByUserId()
        );
    }
}
