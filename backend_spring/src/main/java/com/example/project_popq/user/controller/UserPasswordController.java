package com.example.project_popq.user.controller;

import com.example.project_popq.auth.dto.AckResponse;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.ChangePasswordRequest;
import com.example.project_popq.user.service.UserPasswordService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class UserPasswordController {

    private final CurrentUserService currentUserService;
    private final UserPasswordService userPasswordService;

    @PostMapping("/password")
    public ApiResponse<AckResponse> changePassword(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ChangePasswordRequest request
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        userPasswordService.changePassword(
                userId,
                request.currentPassword(),
                request.newPassword()
        );
        return ApiResponse.success(AckResponse.ok());
    }
}
