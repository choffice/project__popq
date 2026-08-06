package com.example.project_popq.user.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.NotificationPreferenceResponse;
import com.example.project_popq.user.dto.UpdateNotificationPreferenceRequest;
import com.example.project_popq.user.service.UserNotificationPreferenceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me/notification-preferences")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class UserNotificationPreferenceController {

    private final CurrentUserService currentUserService;
    private final UserNotificationPreferenceService userNotificationPreferenceService;

    @GetMapping
    public ApiResponse<NotificationPreferenceResponse> get(
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        return ApiResponse.success(userNotificationPreferenceService.get(userId));
    }

    @PatchMapping
    public ApiResponse<NotificationPreferenceResponse> update(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UpdateNotificationPreferenceRequest request
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        return ApiResponse.success(
                userNotificationPreferenceService.update(
                        userId,
                        request.pushNotificationEnabled(),
                        request.marketingOptIn()
                )
        );
    }
}
