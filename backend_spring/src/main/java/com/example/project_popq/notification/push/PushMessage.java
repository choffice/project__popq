package com.example.project_popq.notification.push;

import java.util.Map;

public record PushMessage(
        String token,
        String title,
        String body,
        Map<String, String> data
) {
}
