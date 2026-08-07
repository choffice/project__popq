package com.example.project_popq.user.controller;

import com.example.project_popq.auth.dto.AckResponse;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.UpdateNameRequest;
import com.example.project_popq.user.service.UserNameService;
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
@RequestMapping("/api/v1/users/me")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class UserNameController {

    private final CurrentUserService currentUserService;
    private final UserNameService userNameService;

    @PatchMapping("/name")
    public ApiResponse<AckResponse> updateName(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UpdateNameRequest request
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        userNameService.updateName(userId, request.name());
        return ApiResponse.success(AckResponse.ok());
    }
}
