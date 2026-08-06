package com.example.project_popq.engagement.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.engagement.domain.Review;
import com.example.project_popq.engagement.domain.ReviewStatus;
import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.engagement.dto.UpsertReviewRequest;
import com.example.project_popq.engagement.repository.ReviewRepository;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.util.List;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final OrderRepository orderRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional
    public ReviewResponse create(
            User user,
            String orderPublicId,
            UpsertReviewRequest request
    ) {
        requireCustomer(user);
        Order order = orderRepository
                .findByOrderPublicIdAndUserId(orderPublicId, user.getId())
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
        if (order.getStatus() != OrderStatus.COMPLETED) {
            throw new BusinessException(ErrorCode.REVIEW_NOT_ALLOWED);
        }
        if (reviewRepository.existsByOrderId(order.getId())) {
            throw new BusinessException(ErrorCode.REVIEW_ALREADY_EXISTS);
        }
        Review review = reviewRepository.save(
                Review.create(
                        order,
                        user,
                        request.rating(),
                        normalize(request.content())
                )
        );
        reviewRepository.flush();
        return ReviewResponse.from(review);
    }

    @Transactional
    public ReviewResponse update(
            User user,
            Long reviewId,
            UpsertReviewRequest request
    ) {
        Review review = requireOwnedActive(user, reviewId);
        review.update(request.rating(), normalize(request.content()));
        reviewRepository.flush();
        return ReviewResponse.from(review);
    }

    @Transactional
    public ReviewResponse delete(User user, Long reviewId) {
        Review review = requireOwnedActive(user, reviewId);
        review.delete();
        reviewRepository.flush();
        return ReviewResponse.from(review);
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> findMine(User user) {
        requireCustomer(user);
        return reviewRepository
                .findAllByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(ReviewResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> findPublicStoreReviews(Long storeId) {
        return reviewRepository
                .findAllByStoreIdAndStatusOrderByCreatedAtDesc(
                        storeId,
                        ReviewStatus.ACTIVE
                )
                .stream()
                .map(ReviewResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> findSellerStoreReviews(
            User user,
            Long storeId,
            Integer rating,
            Boolean unanswered
    ) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
        if (rating != null && (rating < 1 || rating > 5)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
        return reviewRepository
                .findAllByStoreIdAndStatusOrderByCreatedAtDesc(
                        storeId,
                        ReviewStatus.ACTIVE
                )
                .stream()
                .filter(review -> rating == null || review.getRating() == rating)
                .filter(review -> !Boolean.TRUE.equals(unanswered)
                        || review.getSellerReply() == null)
                .map(ReviewResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public ReviewResponse findSellerOrderReview(
            User user,
            Long storeId,
            String orderPublicId
    ) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
        return reviewRepository.findByOrderOrderPublicIdAndStoreIdAndStatus(
                        orderPublicId,
                        storeId,
                        ReviewStatus.ACTIVE
                )
                .map(ReviewResponse::from)
                .orElse(null);
    }

    @Transactional
    public ReviewResponse replyAsSeller(
            User user,
            Long storeId,
            Long reviewId,
            String reply
    ) {
        requireSellerReviewWriter(user, storeId);
        Review review = requireActiveStoreReview(reviewId, storeId);
        review.reply(reply.trim(), user.getId(), Instant.now());
        reviewRepository.flush();
        return ReviewResponse.from(review);
    }

    @Transactional
    public ReviewResponse deleteSellerReply(
            User user,
            Long storeId,
            Long reviewId
    ) {
        requireSellerReviewWriter(user, storeId);
        Review review = requireActiveStoreReview(reviewId, storeId);
        review.deleteReply();
        reviewRepository.flush();
        return ReviewResponse.from(review);
    }

    private void requireSellerReviewWriter(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
    }

    private Review requireActiveStoreReview(Long reviewId, Long storeId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new BusinessException(ErrorCode.REVIEW_NOT_FOUND));
        if (!review.getStore().getId().equals(storeId)
                || review.getStatus() != ReviewStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.REVIEW_NOT_FOUND);
        }
        return review;
    }

    private Review requireOwnedActive(User user, Long reviewId) {
        requireCustomer(user);
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.REVIEW_NOT_FOUND
                ));
        if (!review.belongsTo(user.getId())
                || review.getStatus() != ReviewStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.REVIEW_NOT_FOUND);
        }
        return review;
    }

    private void requireCustomer(User user) {
        if (!user.hasRole(PlatformRole.CUSTOMER)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
