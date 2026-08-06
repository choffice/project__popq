package com.example.project_popq.payment.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.payment.kakao")
public record KakaoPaymentProperties(
        String apiBaseUrl,
        String secretKey,
        String cid,
        String cidSecret,
        String approvalUrl,
        String cancelUrl,
        String failUrl,
        String redirectSchemeUrl,
        Duration readyTtl
) {

    private static final String DEFAULT_API_BASE_URL =
            "https://open-api.kakaopay.com";

    private static final String DEFAULT_TEST_CID =
            "TC0ONETIME";

    private static final Duration DEFAULT_READY_TTL =
            Duration.ofMinutes(15);

    public String resolvedApiBaseUrl() {
        if (isBlank(apiBaseUrl)) {
            return DEFAULT_API_BASE_URL;
        }

        return apiBaseUrl.endsWith("/")
                ? apiBaseUrl.substring(
                0,
                apiBaseUrl.length() - 1
        )
                : apiBaseUrl;
    }

    public String resolvedCid() {
        return isBlank(cid)
                ? DEFAULT_TEST_CID
                : cid;
    }

    public Duration resolvedReadyTtl() {
        if (readyTtl == null
                || readyTtl.isZero()
                || readyTtl.isNegative()) {
            return DEFAULT_READY_TTL;
        }

        return readyTtl;
    }

    public boolean hasSecretKey() {
        return !isBlank(secretKey);
    }

    public boolean hasCidSecret() {
        return !isBlank(cidSecret);
    }

    public boolean hasApprovalUrl() {
        return !isBlank(approvalUrl);
    }

    public boolean hasCancelUrl() {
        return !isBlank(cancelUrl);
    }

    public boolean hasFailUrl() {
        return !isBlank(failUrl);
    }

    public boolean hasRedirectSchemeUrl() {
        return !isBlank(redirectSchemeUrl);
    }

    public boolean hasRequiredCallbackUrls() {
        return hasApprovalUrl()
                && hasCancelUrl()
                && hasFailUrl();
    }

    private boolean isBlank(
            String value
    ) {
        return value == null
                || value.isBlank();
    }
}