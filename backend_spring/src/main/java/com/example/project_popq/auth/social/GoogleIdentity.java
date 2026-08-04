package com.example.project_popq.auth.social;

public record GoogleIdentity(
    String providerUserId,
    String email,
    String name,
    boolean emailVerified
) {
}