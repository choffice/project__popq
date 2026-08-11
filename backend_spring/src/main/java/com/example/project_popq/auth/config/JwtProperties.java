package com.example.project_popq.auth.config;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.security.jwt")
public record JwtProperties(
    String issuer,
    String secret,
    Duration accessTokenExpiration,
    Duration refreshTokenExpiration
) {
}