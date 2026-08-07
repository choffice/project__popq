package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.StoreScheduleExceptionType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record StoreScheduleExceptionRequest(
        @NotNull LocalDate startDate,
        @NotNull LocalDate endDate,
        @NotNull StoreScheduleExceptionType exceptionType,
        @Size(max = 255) String memo
) {
}
