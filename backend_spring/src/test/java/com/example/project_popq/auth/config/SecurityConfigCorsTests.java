package com.example.project_popq.auth.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.project_popq.qr.config.QrProperties;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;

class SecurityConfigCorsTests {

    @Test
    void qrPublicOriginIsAllowedWithoutDuplicatingEnvironmentList() {
        QrProperties qrProperties = new QrProperties(
                "https://order.popq.test/menu",
                Duration.ofHours(12),
                true,
                "test-encryption-key"
        );
        CorsConfigurationSource source = new SecurityConfig()
                .corsConfigurationSource(
                        List.of("https://seller.popq.test"),
                        qrProperties
                );
        MockHttpServletRequest request = new MockHttpServletRequest(
                "OPTIONS",
                "/api/v1/qr/token/sessions"
        );

        CorsConfiguration configuration = source.getCorsConfiguration(request);

        assertThat(configuration).isNotNull();
        assertThat(configuration.checkOrigin("https://order.popq.test"))
                .isEqualTo("https://order.popq.test");
        assertThat(configuration.checkOrigin("https://seller.popq.test"))
                .isEqualTo("https://seller.popq.test");
        assertThat(configuration.checkOrigin("https://malicious.example"))
                .isNull();
        assertThat(configuration.getAllowCredentials()).isTrue();
    }
}
