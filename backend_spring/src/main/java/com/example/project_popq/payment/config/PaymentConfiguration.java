package com.example.project_popq.payment.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({
    PaymentProperties.class,
    TossPaymentProperties.class,
    KakaoPaymentProperties.class
})
public class PaymentConfiguration {
}