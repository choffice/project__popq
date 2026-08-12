package com.example.project_popq.auth.dto;

public record AuthTokenResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresIn,
    AuthUserResponse user
) {
}