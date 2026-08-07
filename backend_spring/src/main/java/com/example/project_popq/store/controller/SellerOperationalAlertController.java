package com.example.project_popq.store.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.store.dto.SellerOperationalAlertsResponse;
import com.example.project_popq.store.service.SellerOperationalAlertService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/alerts")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerOperationalAlertController {

    private final CurrentUserService currentUserService;
    private final SellerOperationalAlertService alertService;

    @GetMapping
    public ApiResponse<SellerOperationalAlertsResponse> find(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "30") int limit
    ) {
        return ApiResponse.success(
                alertService.find(currentUserService.getRequired(jwt), limit)
        );
    }
}
