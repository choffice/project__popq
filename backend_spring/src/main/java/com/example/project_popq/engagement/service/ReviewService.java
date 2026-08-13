package com.example.project_popq.engagement.service;

import com.example.project_popq.activity.service.CustomerActivityService;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.engagement.domain.Review;
import com.example.project_popq.engagement.domain.ReviewStatus;
import com.example.project_popq.engagement.domain.SellerReviewReplyTemplate;
import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.engagement.dto.SellerReviewReplyTemplateResponse;
import com.example.project_popq.engagement.dto.UpsertReviewRequest;
import com.example.project_popq.engagement.repository.ReviewRepository;
import com.example.project_popq.engagement.repository.SellerReviewReplyTemplateRepository;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.repository.StoreRepository;
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
    private final StoreRepository storeRepository;
    private final SellerReviewReplyTemplateRepository replyTemplateRepository;
    private final CustomerActivityService customerActivityService;

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
                        normalize(request.content()),
                        normalize(request.imageUrl())
                )
        );
        reviewRepository.flush();
        return toResponse(review);
    }

    @Transactional
    public ReviewResponse update(
            User user,
            Long reviewId,
            UpsertReviewRequest request
    ) {
        Review review = requireOwnedActive(user, reviewId);
        review.update(
                request.rating(),
                normalize(request.content()),
                normalize(request.imageUrl())
        );
        reviewRepository.flush();
        return toResponse(review);
    }

    @Transactional
    public ReviewResponse delete(User user, Long reviewId) {
        Review review = requireOwnedActive(user, reviewId);
        review.delete();
        reviewRepository.flush();
        return toResponse(review);
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> findMine(User user) {
        requireCustomer(user);
        return reviewRepository
                .findAllByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(this::toResponse)
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
                .map(this::toResponse)
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
                .map(this::toResponse)
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
                .map(this::toResponse)
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
        return toResponse(review);
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
        return toResponse(review);
    }

    @Transactional(readOnly = true)
    public List<SellerReviewReplyTemplateResponse> findReplyTemplates(
            User user,
            Long storeId
    ) {
        storeAuthorizationService.requireAnyRole(
                user.getId(), storeId,
                StoreRole.OWNER, StoreRole.MANAGER, StoreRole.STAFF
        );
        return replyTemplateRepository.findAllByStoreIdOrderByIdAsc(storeId)
                .stream()
                .map(SellerReviewReplyTemplateResponse::from)
                .toList();
    }

    @Transactional
    public SellerReviewReplyTemplateResponse createReplyTemplate(
            User user,
            Long storeId,
            String content
    ) {
        requireSellerReviewWriter(user, storeId);
        if (replyTemplateRepository.countByStoreId(storeId) >= 20) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
        var store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        return SellerReviewReplyTemplateResponse.from(
                replyTemplateRepository.save(
                        SellerReviewReplyTemplate.create(store, content.trim())
                )
        );
    }

    @Transactional
    public SellerReviewReplyTemplateResponse updateReplyTemplate(
            User user,
            Long storeId,
            Long templateId,
            String content
    ) {
        requireSellerReviewWriter(user, storeId);
        SellerReviewReplyTemplate template = requireReplyTemplate(
                storeId, templateId
        );
        template.update(content.trim());
        return SellerReviewReplyTemplateResponse.from(template);
    }

    @Transactional
    public void deleteReplyTemplate(User user, Long storeId, Long templateId) {
        requireSellerReviewWriter(user, storeId);
        replyTemplateRepository.delete(requireReplyTemplate(storeId, templateId));
    }

    private SellerReviewReplyTemplate requireReplyTemplate(
            Long storeId,
            Long templateId
    ) {
        return replyTemplateRepository.findByIdAndStoreId(templateId, storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_REQUEST));
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

    private ReviewResponse toResponse(Review review) {
        return ReviewResponse.from(
                review,
                customerActivityService.getPublicBadgeTier(review.getUser())
        );
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
