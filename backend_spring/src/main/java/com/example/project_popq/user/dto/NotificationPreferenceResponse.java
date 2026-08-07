package com.example.project_popq.user.dto;

public record NotificationPreferenceResponse(
        boolean pushNotificationEnabled,
        boolean marketingOptIn
) {
}
