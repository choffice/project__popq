package com.example.project_popq.engagement.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.engagement.service.ReviewService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/public/stores/{storeId}/reviews")
@RequiredArgsConstructor
public class PublicReviewController {

    private final ReviewService reviewService;

    @GetMapping
    public ApiResponse<List<ReviewResponse>> findAll(
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                reviewService.findPublicStoreReviews(storeId)
        );
    }
}
