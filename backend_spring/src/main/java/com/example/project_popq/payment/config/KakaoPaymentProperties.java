package com.example.project_popq.payment.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.payment.kakao")
public record KakaoPaymentProperties(
        String apiBaseUrl,
        String secretKey,
        String cid,
        String cidSecret
) {

    public String resolvedApiBaseUrl() {
        if (apiBaseUrl == null || apiBaseUrl.isBlank()) {
            return "https://open-api.kakaopay.com";
        }

        return apiBaseUrl.endsWith("/")
                ? apiBaseUrl.substring(
                0,
                apiBaseUrl.length() - 1
        )
                : apiBaseUrl;
    }

    public String resolvedCid() {
        return cid == null || cid.isBlank()
                ? "TC0ONETIME"
                : cid;
    }

    public boolean hasSecretKey() {
        return secretKey != null
                && !secretKey.isBlank();
    }

    public boolean hasCidSecret() {
        return cidSecret != null
                && !cidSecret.isBlank();
    }
}