package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreType;
import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.List;

public record PublicStoreResponse(
        Long storeId,
        StoreType storeType,
        String name,
        String description,
        BusinessStatus businessStatus,
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
        List<String> tags,
        Long distanceMeters
) {
    public static PublicStoreResponse of(
            Store store,
            List<String> tags,
            Long distanceMeters
    ) {
        return new PublicStoreResponse(
                store.getId(),
                store.getStoreType(),
                store.getName(),
                store.getDescription(),
                store.getBusinessStatus(),
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
                tags,
                distanceMeters
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
