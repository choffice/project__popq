package com.example.project_popq.user.controller;

import com.example.project_popq.auth.dto.AckResponse;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.UpdatePhoneRequest;
import com.example.project_popq.user.service.UserContactService;
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
public class UserContactController {

    private final CurrentUserService currentUserService;
    private final UserContactService userContactService;

    @PatchMapping("/phone")
    public ApiResponse<AckResponse> updatePhone(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UpdatePhoneRequest request
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        userContactService.updatePhone(userId, request.phone());
        return ApiResponse.success(AckResponse.ok());
    }
}
