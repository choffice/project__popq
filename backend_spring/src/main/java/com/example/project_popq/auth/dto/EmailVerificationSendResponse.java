package com.example.project_popq.auth.dto;

public record EmailVerificationSendResponse(
        long expiresInSeconds,
        long resendAfterSeconds
) {
}
