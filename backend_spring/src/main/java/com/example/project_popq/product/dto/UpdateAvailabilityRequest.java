package com.example.project_popq.product.dto;

import java.time.Instant;

public record UpdateAvailabilityRequest(
        boolean soldOut,
        Instant salesStartAt,
        Instant salesEndAt,
        boolean qrWebEnabled,
        boolean customerAppEnabled
) {
}

