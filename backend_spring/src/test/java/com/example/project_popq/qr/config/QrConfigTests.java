package com.example.project_popq.qr.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class QrConfigTests {

    @Test
    void productionRequiresPublicHttpsAndSecureGuestCookie() {
        MockEnvironment production = new MockEnvironment();
        production.setActiveProfiles("prod");

        assertThatIllegalStateException().isThrownBy(() -> new QrConfig(
                properties("http://localhost:5173", true),
                production
        ));
        assertThatIllegalStateException().isThrownBy(() -> new QrConfig(
                properties("https://order.popq.test", false),
                production
        ));
        assertThatCode(() -> new QrConfig(
                properties("https://order.popq.test", true),
                production
        )).doesNotThrowAnyException();
    }

    @Test
    void developmentAllowsLocalQrWeb() {
        assertThatCode(() -> new QrConfig(
                properties("http://localhost:5173", false),
                new MockEnvironment().withProperty(
                        "spring.profiles.active",
                        "dev"
                )
        )).doesNotThrowAnyException();
    }

    private QrProperties properties(String publicBaseUrl, boolean secureCookie) {
        return new QrProperties(
                publicBaseUrl,
                Duration.ofHours(12),
                secureCookie,
                "test-encryption-key"
        );
    }
}
