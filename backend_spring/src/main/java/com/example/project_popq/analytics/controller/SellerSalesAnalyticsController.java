package com.example.project_popq.analytics.controller;

import com.example.project_popq.analytics.dto.SalesSummaryResponse;
import com.example.project_popq.analytics.service.SalesAnalyticsService;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores/{storeId}/analytics")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerSalesAnalyticsController {

    private final CurrentUserService currentUserService;
    private final SalesAnalyticsService salesAnalyticsService;

    @GetMapping("/sales")
    public ApiResponse<SalesSummaryResponse> sales(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate to
    ) {
        return ApiResponse.success(
                salesAnalyticsService.summarize(
                        currentUserService.getRequired(jwt),
                        storeId,
                        from,
                        to
                )
        );
    }
}
