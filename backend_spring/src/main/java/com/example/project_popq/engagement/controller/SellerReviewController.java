package com.example.project_popq.engagement.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.engagement.dto.SellerReviewReplyRequest;
import com.example.project_popq.engagement.dto.SellerReviewReplyTemplateRequest;
import com.example.project_popq.engagement.dto.SellerReviewReplyTemplateResponse;
import com.example.project_popq.engagement.service.ReviewService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores/{storeId}/reviews")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerReviewController {

    private final CurrentUserService currentUserService;
    private final ReviewService reviewService;

    @GetMapping
    public ApiResponse<List<ReviewResponse>> findAll(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @RequestParam(required = false) Integer rating,
            @RequestParam(required = false) Boolean unanswered
    ) {
        return ApiResponse.success(reviewService.findSellerStoreReviews(
                currentUserService.getRequired(jwt),
                storeId,
                rating,
                unanswered
        ));
    }

    @GetMapping("/orders/{orderPublicId}")
    public ApiResponse<ReviewResponse> findByOrder(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId
    ) {
        return ApiResponse.success(reviewService.findSellerOrderReview(
                currentUserService.getRequired(jwt),
                storeId,
                orderPublicId
        ));
    }

    @PutMapping("/{reviewId}/reply")
    public ApiResponse<ReviewResponse> reply(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long reviewId,
            @Valid @RequestBody SellerReviewReplyRequest request
    ) {
        return ApiResponse.success(reviewService.replyAsSeller(
                currentUserService.getRequired(jwt),
                storeId,
                reviewId,
                request.reply()
        ));
    }

    @DeleteMapping("/{reviewId}/reply")
    public ApiResponse<ReviewResponse> deleteReply(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long reviewId
    ) {
        return ApiResponse.success(reviewService.deleteSellerReply(
                currentUserService.getRequired(jwt),
                storeId,
                reviewId
        ));
    }

    @GetMapping("/reply-templates")
    public ApiResponse<List<SellerReviewReplyTemplateResponse>> findTemplates(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(reviewService.findReplyTemplates(
                currentUserService.getRequired(jwt), storeId
        ));
    }

    @PostMapping("/reply-templates")
    public ApiResponse<SellerReviewReplyTemplateResponse> createTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @Valid @RequestBody SellerReviewReplyTemplateRequest request
    ) {
        return ApiResponse.success(reviewService.createReplyTemplate(
                currentUserService.getRequired(jwt), storeId, request.content()
        ));
    }

    @PatchMapping("/reply-templates/{templateId}")
    public ApiResponse<SellerReviewReplyTemplateResponse> updateTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long templateId,
            @Valid @RequestBody SellerReviewReplyTemplateRequest request
    ) {
        return ApiResponse.success(reviewService.updateReplyTemplate(
                currentUserService.getRequired(jwt), storeId,
                templateId, request.content()
        ));
    }

    @DeleteMapping("/reply-templates/{templateId}")
    public ApiResponse<Void> deleteTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long templateId
    ) {
        reviewService.deleteReplyTemplate(
                currentUserService.getRequired(jwt), storeId, templateId
        );
        return ApiResponse.success(null);
    }
}
