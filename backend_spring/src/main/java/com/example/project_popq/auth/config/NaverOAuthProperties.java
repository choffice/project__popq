package com.example.project_popq.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.social.naver")
public record NaverOAuthProperties(
    String apiBaseUrl,
    String authBaseUrl,
    String clientId,
    String clientSecret,
    String sellerRedirectUri
) {
}
