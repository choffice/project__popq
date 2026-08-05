package com.example.project_popq.qr.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.qr")
public record QrProperties(
        String publicBaseUrl,
        Duration guestSessionTtl,
        boolean cookieSecure,
        String tokenEncryptionKey
) {
}
