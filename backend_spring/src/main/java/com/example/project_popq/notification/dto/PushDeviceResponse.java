package com.example.project_popq.notification.dto;

import com.example.project_popq.notification.domain.DevicePlatform;
import com.example.project_popq.notification.domain.PushDevice;
import java.time.Instant;

public record PushDeviceResponse(
        Long deviceId,
        DevicePlatform platform,
        Instant registeredAt,
        Instant updatedAt
) {
    public static PushDeviceResponse from(PushDevice device) {
        return new PushDeviceResponse(
                device.getId(),
                device.getPlatform(),
                device.getCreatedAt(),
                device.getUpdatedAt()
        );
    }
}
