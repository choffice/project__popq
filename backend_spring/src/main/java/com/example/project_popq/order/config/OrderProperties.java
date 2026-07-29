package com.example.project_popq.order.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.order")
public record OrderProperties(Duration paymentDeadline) {
}

