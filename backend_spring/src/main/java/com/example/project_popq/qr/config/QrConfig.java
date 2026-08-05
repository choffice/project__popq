package com.example.project_popq.qr.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

@Configuration
@EnableConfigurationProperties(QrProperties.class)
public class QrConfig {

    public QrConfig(QrProperties properties, Environment environment) {
        if (!environment.matchesProfiles("prod")) {
            return;
        }
        if (!properties.hasSecurePublicUrl()
                || properties.hasLoopbackPublicHost()) {
            throw new IllegalStateException(
                    "Production QR public base URL must use HTTPS and a "
                            + "non-loopback host"
            );
        }
        if (!properties.cookieSecure()) {
            throw new IllegalStateException(
                    "Production QR guest cookies must be secure"
            );
        }
    }
}

