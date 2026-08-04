package com.example.project_popq.auth.controller;

import com.example.project_popq.auth.dto.AckResponse;
import com.example.project_popq.auth.dto.AuthTokenResponse;
import com.example.project_popq.auth.dto.AuthUserResponse;
import com.example.project_popq.auth.dto.FindIdRequest;
import com.example.project_popq.auth.dto.FindIdResponse;
import com.example.project_popq.auth.dto.LoginRequest;
import com.example.project_popq.auth.dto.PasswordResetConfirmRequest;
import com.example.project_popq.auth.dto.PasswordResetVerifyRequest;
import com.example.project_popq.auth.dto.SignupRequest;
import com.example.project_popq.auth.dto.SocialLoginRequest;
import com.example.project_popq.auth.service.AuthService;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.auth.service.SocialAuthService;
import com.example.project_popq.common.api.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final CurrentUserService currentUserService;
    private final AuthService authService;
    private final SocialAuthService socialAuthService;

    @GetMapping("/me")
    public ApiResponse<AuthUserResponse> me(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(
                AuthUserResponse.from(currentUserService.getRequired(jwt))
        );
    }

    @PostMapping("/signup")
    public ResponseEntity<ApiResponse<AuthTokenResponse>> signup(
            @Valid @RequestBody SignupRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(authService.signup(request)));
    }

    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(
            @Valid @RequestBody LoginRequest request
    ) {
        return ApiResponse.success(authService.login(request));
    }

    @PostMapping("/find-id")
    public ApiResponse<FindIdResponse> findId(
            @Valid @RequestBody FindIdRequest request
    ) {
        return ApiResponse.success(authService.findId(request));
    }
    @PostMapping("/social/login")
    public ApiResponse<AuthTokenResponse> socialLogin(
        @Valid @RequestBody SocialLoginRequest request
    ) {
        return ApiResponse.success(
            socialAuthService.login(request)
        );
    }

    @PostMapping("/password-reset/verify")
    public ApiResponse<AckResponse> verifyForPasswordReset(
            @Valid @RequestBody PasswordResetVerifyRequest request
    ) {
        return ApiResponse.success(authService.verifyForPasswordReset(request));
    }

    @PostMapping("/password-reset/confirm")
    public ApiResponse<AckResponse> confirmPasswordReset(
            @Valid @RequestBody PasswordResetConfirmRequest request
    ) {
        return ApiResponse.success(authService.resetPassword(request));
    }
}

