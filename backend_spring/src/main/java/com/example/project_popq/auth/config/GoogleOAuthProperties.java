package com.example.project_popq.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.social.google")
public record GoogleOAuthProperties(
    String clientId
) {
}