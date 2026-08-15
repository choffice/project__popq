package com.example.project_popq.auth.dto;

public record DevLoginResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresIn,
    AuthUserResponse user
) {
}