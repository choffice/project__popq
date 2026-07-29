package com.example.project_popq.engagement.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.engagement.dto.CustomerProfileResponse;
import com.example.project_popq.engagement.dto.InterestStateResponse;
import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.engagement.dto.StoreInterestResponse;
import com.example.project_popq.engagement.dto.UpsertReviewRequest;
import com.example.project_popq.engagement.service.CustomerProfileService;
import com.example.project_popq.engagement.service.ReviewService;
import com.example.project_popq.engagement.service.StoreInterestService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customer")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerEngagementController {

    private final CurrentUserService currentUserService;
    private final StoreInterestService storeInterestService;
    private final ReviewService reviewService;
    private final CustomerProfileService customerProfileService;

    @GetMapping("/profile")
    public ApiResponse<CustomerProfileResponse> profile(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                customerProfileService.get(currentUserService.getRequired(jwt))
        );
    }

    @GetMapping("/store-interests")
    public ApiResponse<List<StoreInterestResponse>> interests(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                storeInterestService.findAll(currentUserService.getRequired(jwt))
        );
    }

    @GetMapping("/store-interests/{storeId}")
    public ApiResponse<InterestStateResponse> interestState(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                storeInterestService.getState(
                        currentUserService.getRequired(jwt),
                        storeId
                )
        );
    }

    @PostMapping("/store-interests/{storeId}")
    public ApiResponse<InterestStateResponse> addInterest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                storeInterestService.add(
                        currentUserService.getRequired(jwt),
                        storeId
                )
        );
    }

    @DeleteMapping("/store-interests/{storeId}")
    public ApiResponse<InterestStateResponse> removeInterest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                storeInterestService.remove(
                        currentUserService.getRequired(jwt),
                        storeId
                )
        );
    }

    @GetMapping("/reviews")
    public ApiResponse<List<ReviewResponse>> myReviews(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                reviewService.findMine(currentUserService.getRequired(jwt))
        );
    }

    @PostMapping("/reviews/orders/{orderPublicId}")
    public ResponseEntity<ApiResponse<ReviewResponse>> createReview(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String orderPublicId,
            @Valid @RequestBody UpsertReviewRequest request
    ) {
        ReviewResponse created = reviewService.create(
                currentUserService.getRequired(jwt),
                orderPublicId,
                request
        );
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(created));
    }

    @PutMapping("/reviews/{reviewId}")
    public ApiResponse<ReviewResponse> updateReview(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long reviewId,
            @Valid @RequestBody UpsertReviewRequest request
    ) {
        return ApiResponse.success(
                reviewService.update(
                        currentUserService.getRequired(jwt),
                        reviewId,
                        request
                )
        );
    }

    @DeleteMapping("/reviews/{reviewId}")
    public ApiResponse<ReviewResponse> deleteReview(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long reviewId
    ) {
        return ApiResponse.success(
                reviewService.delete(
                        currentUserService.getRequired(jwt),
                        reviewId
                )
        );
    }
}
