package com.example.project_popq.store.dto;

import jakarta.validation.constraints.NotNull;
import java.time.DayOfWeek;
import java.time.LocalTime;

public record StoreBusinessHourRequest(
        @NotNull DayOfWeek dayOfWeek,
        boolean closed,
        boolean open24Hours,
        LocalTime openTime,
        LocalTime closeTime
) {
}
