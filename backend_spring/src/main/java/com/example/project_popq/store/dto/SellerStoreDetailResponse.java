package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;
import java.math.BigDecimal;
import java.util.List;

public record SellerStoreDetailResponse(
        Long storeId,
        StoreType storeType,
        String name,
        String description,
        String address,
        BigDecimal latitude,
        BigDecimal longitude,
        List<String> tags,
        StoreStatus status,
        BusinessStatus businessStatus,
        StoreRole myRole
) {
    public static SellerStoreDetailResponse of(
            Store store,
            StoreRole myRole,
            List<String> tags
    ) {
        return new SellerStoreDetailResponse(
                store.getId(),
                store.getStoreType(),
                store.getName(),
                store.getDescription(),
                store.getAddress(),
                store.getLatitude(),
                store.getLongitude(),
                List.copyOf(tags),
                store.getStatus(),
                store.getBusinessStatus(),
                myRole
        );
    }
}
