package com.example.project_popq.realtime.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "popq.realtime")
public record RealtimeProperties(
        List<String> allowedOriginPatterns
) {
}
