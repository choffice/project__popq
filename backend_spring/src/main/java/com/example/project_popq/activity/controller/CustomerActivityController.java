package com.example.project_popq.activity.controller;

import com.example.project_popq.activity.dto.CustomerAttendanceResponse;
import com.example.project_popq.activity.dto.CustomerActivitySummaryResponse;
import com.example.project_popq.activity.dto.RecordQrVisitRequest;
import com.example.project_popq.activity.dto.RecordVisitResponse;
import com.example.project_popq.activity.service.CustomerActivityService;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.domain.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customer/activities")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerActivityController {

    private final CurrentUserService currentUserService;
    private final CustomerActivityService customerActivityService;

    @GetMapping("/summary")
    public ApiResponse<CustomerActivitySummaryResponse> summary(
            @AuthenticationPrincipal Jwt jwt
    ) {
        User user = currentUserService.getRequired(jwt);
        return ApiResponse.success(customerActivityService.getSummary(user));
    }

    @GetMapping("/attendance")
    public ApiResponse<CustomerAttendanceResponse> attendance(
            @AuthenticationPrincipal Jwt jwt
    ) {
        User user = currentUserService.getRequired(jwt);
        return ApiResponse.success(customerActivityService.getAttendance(user));
    }

    @PostMapping("/attendance")
    public ApiResponse<CustomerAttendanceResponse> recordAttendance(
            @AuthenticationPrincipal Jwt jwt
    ) {
        User user = currentUserService.getRequired(jwt);
        return ApiResponse.success(customerActivityService.recordAttendance(user));
    }

    @PostMapping("/visits")
    public ApiResponse<RecordVisitResponse> recordVisit(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody RecordQrVisitRequest request
    ) {
        User user = currentUserService.getRequired(jwt);
        return ApiResponse.success(
                customerActivityService.recordQrVisit(user, request.qrToken())
        );
    }
}
