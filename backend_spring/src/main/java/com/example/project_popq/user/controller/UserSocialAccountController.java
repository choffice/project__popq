package com.example.project_popq.user.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.LinkedSocialAccountsResponse;
import com.example.project_popq.user.service.UserSocialAccountService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me/social-accounts")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class UserSocialAccountController {

    private final CurrentUserService currentUserService;
    private final UserSocialAccountService userSocialAccountService;

    @GetMapping
    public ApiResponse<LinkedSocialAccountsResponse> list(
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        return ApiResponse.success(userSocialAccountService.list(userId));
    }
}
