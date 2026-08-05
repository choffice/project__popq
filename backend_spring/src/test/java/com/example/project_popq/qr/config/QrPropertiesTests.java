package com.example.project_popq.qr.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class QrPropertiesTests {

    @Test
    void normalizesPublicBaseUrlAndBuildsTokenUrl() {
        QrProperties properties = properties(
                "https://order.popq.test/order/"
        );

        assertThat(properties.publicBaseUrl())
                .isEqualTo("https://order.popq.test/order");
        assertThat(properties.publicOrigin())
                .isEqualTo("https://order.popq.test");
        assertThat(properties.publicUrlForToken("token-123"))
                .isEqualTo("https://order.popq.test/order/q/token-123");
    }

    @Test
    void rejectsNonHttpAndAmbiguousPublicBaseUrls() {
        assertThatIllegalArgumentException()
                .isThrownBy(() -> properties("javascript:alert(1)"));
        assertThatIllegalArgumentException()
                .isThrownBy(() -> properties(
                        "https://order.popq.test?redirect=other"
                ));
        assertThatIllegalArgumentException()
                .isThrownBy(() -> properties("/relative/path"));
    }

    @Test
    void identifiesProductionSafeAndLoopbackUrls() {
        assertThat(properties("https://order.popq.test").hasSecurePublicUrl())
                .isTrue();
        assertThat(properties("https://order.popq.test").hasLoopbackPublicHost())
                .isFalse();
        assertThat(properties("http://127.0.0.1:5173").hasLoopbackPublicHost())
                .isTrue();
    }

    private QrProperties properties(String publicBaseUrl) {
        return new QrProperties(
                publicBaseUrl,
                Duration.ofHours(12),
                false,
                "test-encryption-key"
        );
    }
}
