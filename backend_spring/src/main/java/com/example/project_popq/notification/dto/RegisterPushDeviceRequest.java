package com.example.project_popq.notification.dto;

import com.example.project_popq.notification.domain.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record RegisterPushDeviceRequest(
        @NotBlank @Size(max = 512) String token,
        @NotNull DevicePlatform platform
) {
}
