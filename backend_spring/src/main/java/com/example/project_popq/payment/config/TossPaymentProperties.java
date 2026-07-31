package com.example.project_popq.payment.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.payment.toss")
public record TossPaymentProperties(
    String apiBaseUrl,
    String secretKey
) {
}