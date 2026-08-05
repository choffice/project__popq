package com.example.project_popq.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.social.kakao")
public record KakaoOAuthProperties(
    String apiBaseUrl,
    Long customerAppId,
    Long sellerAppId
) {
}