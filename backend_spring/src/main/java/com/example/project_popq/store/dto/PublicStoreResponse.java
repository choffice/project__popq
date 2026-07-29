package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreType;
import java.math.BigDecimal;
import java.util.List;

public record PublicStoreResponse(
        Long storeId,
        StoreType storeType,
        String name,
        String description,
        BusinessStatus businessStatus,
        String address,
        BigDecimal latitude,
        BigDecimal longitude,
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
                store.getLatitude(),
                store.getLongitude(),
                tags,
                distanceMeters
        );
    }
}
