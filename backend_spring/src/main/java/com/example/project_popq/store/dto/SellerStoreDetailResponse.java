package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.List;

public record SellerStoreDetailResponse(
        Long storeId,
        StoreType storeType,
        String name,
        String description,
        String address,
        String detailAddress,
        String representativeCategory,
        String imageUrl,
        String phone,
        BigDecimal latitude,
        BigDecimal longitude,
        LocalTime openTime,
        LocalTime closeTime,
        List<DayOfWeek> closedDays,
        boolean takeoutAvailable,
        boolean dineInAvailable,
        boolean orderAcceptingEnabled,
        Integer defaultPreparationMinutes,
        List<String> tags,
        StoreStatus status,
        BusinessStatus businessStatus,
        StoreRole myRole,
        StoreScheduleResponse schedule
) {

    public static SellerStoreDetailResponse of(
            Store store,
            StoreRole myRole,
            List<String> tags,
            StoreScheduleResponse schedule
    ) {
        return new SellerStoreDetailResponse(
                store.getId(),
                store.getStoreType(),
                store.getName(),
                store.getDescription(),
                store.getAddress(),
                store.getDetailAddress(),
                store.getRepresentativeCategory(),
                store.getImageUrl(),
                store.getPhone(),
                store.getLatitude(),
                store.getLongitude(),
                store.getOpenTime(),
                store.getCloseTime(),
                parseClosedDays(store.getClosedDays()),
                store.isTakeoutAvailable(),
                store.isDineInAvailable(),
                store.isOrderAcceptingEnabled(),
                store.getDefaultPreparationMinutes(),
                List.copyOf(tags),
                store.getStatus(),
                store.getBusinessStatus(),
                myRole,
                schedule
        );
    }

    private static List<DayOfWeek> parseClosedDays(String closedDays) {
        if (closedDays == null || closedDays.isBlank()) {
            return List.of();
        }

        return Arrays.stream(closedDays.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(String::toUpperCase)
                .map(DayOfWeek::valueOf)
                .distinct()
                .toList();
    }
}
