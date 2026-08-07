package com.example.project_popq.user.controller;

import com.example.project_popq.auth.dto.AckResponse;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.dto.LinkSocialAccountRequest;
import com.example.project_popq.user.dto.LinkedSocialAccountsResponse;
import com.example.project_popq.user.service.UserSocialAccountService;
import com.example.project_popq.user.service.UserSocialLinkService;
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
@RequestMapping("/api/v1/users/me/social-accounts")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class UserSocialAccountController {

    private final CurrentUserService currentUserService;
    private final UserSocialAccountService userSocialAccountService;
    private final UserSocialLinkService userSocialLinkService;

    @GetMapping
    public ApiResponse<LinkedSocialAccountsResponse> list(
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        return ApiResponse.success(userSocialAccountService.list(userId));
    }

    @PostMapping
    public ApiResponse<AckResponse> link(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody LinkSocialAccountRequest request
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        PlatformRole activeRole = PlatformRole.valueOf(jwt.getClaimAsString("role"));

        userSocialLinkService.link(
                userId,
                activeRole,
                request.provider(),
                request.providerToken()
        );

        return ApiResponse.success(AckResponse.ok());
    }
}
