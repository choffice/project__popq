package com.example.project_popq.auth.dto;

public record DevLoginResponse(
        String accessToken,
        String tokenType,
        long expiresIn,
        AuthUserResponse user
) {
}

