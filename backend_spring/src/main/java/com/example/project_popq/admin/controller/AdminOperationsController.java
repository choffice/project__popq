package com.example.project_popq.admin.controller;

import com.example.project_popq.admin.dto.AdminOverviewResponse;
import com.example.project_popq.admin.dto.AdminSellerResponse;
import com.example.project_popq.admin.dto.AdminStoreResponse;
import com.example.project_popq.admin.dto.AdminUserResponse;
import com.example.project_popq.admin.dto.UpdateAdminStatuses.SellerVerificationRequest;
import com.example.project_popq.admin.dto.UpdateAdminStatuses.StoreStatusRequest;
import com.example.project_popq.admin.dto.UpdateAdminStatuses.UserStatusRequest;
import com.example.project_popq.admin.service.AdminOperationsService;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.common.api.PageResponse;
import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.UserStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminOperationsController {

    private final CurrentUserService currentUserService;
    private final AdminOperationsService adminOperationsService;

    @GetMapping("/overview")
    public ApiResponse<AdminOverviewResponse> overview(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                adminOperationsService.overview(currentUserService.getRequired(jwt))
        );
    }

    @GetMapping("/users")
    public ApiResponse<PageResponse<AdminUserResponse>> users(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) PlatformRole role,
            @RequestParam(required = false) UserStatus status,
            @RequestParam(defaultValue = "desc") String sort
    ) {
        return ApiResponse.success(
                adminOperationsService.users(
                        currentUserService.getRequired(jwt),
                        page,
                        size,
                        query,
                        role,
                        status,
                        sort
                )
        );
    }

    @GetMapping("/sellers")
    public ApiResponse<PageResponse<AdminSellerResponse>> sellers(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) SellerVerificationStatus verificationStatus,
            @RequestParam(required = false) UserStatus userStatus,
            @RequestParam(defaultValue = "desc") String sort
    ) {
        return ApiResponse.success(
                adminOperationsService.sellers(
                        currentUserService.getRequired(jwt),
                        page,
                        size,
                        query,
                        verificationStatus,
                        userStatus,
                        sort
                )
        );
    }

    @GetMapping("/stores")
    public ApiResponse<PageResponse<AdminStoreResponse>> stores(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) StoreStatus status,
            @RequestParam(defaultValue = "desc") String sort
    ) {
        return ApiResponse.success(
                adminOperationsService.stores(
                        currentUserService.getRequired(jwt),
                        page,
                        size,
                        query,
                        status,
                        sort
                )
        );
    }

    @PatchMapping("/users/{userId}/status")
    public ApiResponse<AdminUserResponse> changeUserStatus(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long userId,
            @Valid @RequestBody UserStatusRequest request
    ) {
        return ApiResponse.success(
                adminOperationsService.changeUserStatus(
                        currentUserService.getRequired(jwt),
                        userId,
                        request.status(),
                        request.reason()
                )
        );
    }

    @PatchMapping("/sellers/{sellerProfileId}/verification")
    public ApiResponse<AdminSellerResponse> changeSellerVerification(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long sellerProfileId,
            @Valid @RequestBody SellerVerificationRequest request
    ) {
        return ApiResponse.success(
                adminOperationsService.changeSellerVerification(
                        currentUserService.getRequired(jwt),
                        sellerProfileId,
                        request.verificationStatus(),
                        request.reason()
                )
        );
    }

    @PatchMapping("/stores/{storeId}/status")
    public ApiResponse<AdminStoreResponse> changeStoreStatus(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @Valid @RequestBody StoreStatusRequest request
    ) {
        return ApiResponse.success(
                adminOperationsService.changeStoreStatus(
                        currentUserService.getRequired(jwt),
                        storeId,
                        request.status(),
                        request.reason()
                )
        );
    }
}
