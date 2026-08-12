package com.example.project_popq.user.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.EmblemVisibilityResponse;
import com.example.project_popq.user.dto.UpdateEmblemVisibilityRequest;
import com.example.project_popq.user.service.UserEmblemVisibilityService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me/emblem-visibility")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class UserEmblemVisibilityController {

    private final CurrentUserService currentUserService;
    private final UserEmblemVisibilityService emblemVisibilityService;

    @PatchMapping
    public ApiResponse<EmblemVisibilityResponse> update(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UpdateEmblemVisibilityRequest request
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        return ApiResponse.success(emblemVisibilityService.update(
                userId,
                request.emblemVisible()
        ));
    }
}
