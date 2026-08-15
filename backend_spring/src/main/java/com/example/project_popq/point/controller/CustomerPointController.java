package com.example.project_popq.point.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.point.dto.CustomerPointSummaryResponse;
import com.example.project_popq.point.service.CustomerPointService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customer/points")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerPointController {

    private final CurrentUserService currentUserService;
    private final CustomerPointService customerPointService;

    @GetMapping
    public ApiResponse<CustomerPointSummaryResponse> getSummary(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                customerPointService.getSummary(currentUserService.getRequired(jwt))
        );
    }
}
