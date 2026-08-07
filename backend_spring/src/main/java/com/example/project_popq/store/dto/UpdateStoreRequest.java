package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.StoreType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;

public record UpdateStoreRequest(
        StoreType storeType,

        @NotBlank
        @Size(max = 150)
        String name,

        @Size(max = 1000)
        String description,

        @Size(max = 255)
        String address,

        @Size(max = 255)
        String detailAddress,

        @Size(max = 50)
        String representativeCategory,

        @Size(max = 1000)
        String imageUrl,

        @Size(max = 30)
        String phone,

        @DecimalMin("-90.0")
        @DecimalMax("90.0")
        BigDecimal latitude,

        @DecimalMin("-180.0")
        @DecimalMax("180.0")
        BigDecimal longitude,

        LocalTime openTime,

        LocalTime closeTime,

        @Size(max = 7)
        List<@NotNull DayOfWeek> closedDays,

        Boolean takeoutAvailable,

        Boolean dineInAvailable,

        Boolean orderAcceptingEnabled,

        @Valid
        @Size(max = 10)
        List<@NotBlank @Size(max = 30) String> tags,

        @Valid
        StoreScheduleRequest schedule
) {
}
