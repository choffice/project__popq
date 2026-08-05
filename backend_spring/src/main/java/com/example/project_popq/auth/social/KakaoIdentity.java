package com.example.project_popq.auth.social;

public record KakaoIdentity(
    String providerUserId,
    String email,
    String name
) {
}