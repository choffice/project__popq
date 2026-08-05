package com.example.project_popq.realtime.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.project_popq.qr.config.QrProperties;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

class RealtimeConfigTests {

    @Test
    void qrPublicOriginIsAlwaysAllowedForWebSocketHandshake() {
        QrProperties qrProperties = new QrProperties(
                "https://order.popq.test/menu",
                Duration.ofHours(12),
                true,
                "test-encryption-key"
        );
        RealtimeConfig config = new RealtimeConfig(
                new RealtimeProperties(List.of("https://seller.popq.test")),
                qrProperties,
                null,
                null,
                null
        );

        assertThat(config.allowedOriginPatterns()).containsExactly(
                "https://seller.popq.test",
                "https://order.popq.test"
        );
    }
}
