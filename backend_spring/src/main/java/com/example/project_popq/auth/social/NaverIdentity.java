package com.example.project_popq.auth.social;

public record NaverIdentity(
    String providerUserId,
    String email,
    String name
) {
}