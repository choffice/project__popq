package com.example.project_popq.payment.config;

import com.example.project_popq.payment.domain.PaymentProviderType;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.payment")
public record PaymentProperties(
    PaymentProviderType provider
) {
}