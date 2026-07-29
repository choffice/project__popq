package com.example.project_popq.engagement.dto;

import com.example.project_popq.engagement.domain.Review;
import com.example.project_popq.engagement.domain.ReviewStatus;
import java.time.Instant;

public record ReviewResponse(
        Long reviewId,
        String orderPublicId,
        Long storeId,
        String storeName,
        String authorName,
        int rating,
        String content,
        ReviewStatus status,
        Instant createdAt,
        Instant updatedAt
) {
    public static ReviewResponse from(Review review) {
        return new ReviewResponse(
                review.getId(),
                review.getOrder().getOrderPublicId(),
                review.getStore().getId(),
                review.getStore().getName(),
                review.getUser().getName(),
                review.getRating(),
                review.getContent(),
                review.getStatus(),
                review.getCreatedAt(),
                review.getUpdatedAt()
        );
    }
}
