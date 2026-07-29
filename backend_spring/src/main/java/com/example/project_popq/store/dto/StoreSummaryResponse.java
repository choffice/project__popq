package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;

public record StoreSummaryResponse(
        Long storeId,
        StoreType storeType,
        String name,
        String description,
        StoreStatus status,
        BusinessStatus businessStatus,
        StoreRole myRole
) {
    public static StoreSummaryResponse of(Store store, StoreRole myRole) {
        return new StoreSummaryResponse(
                store.getId(),
                store.getStoreType(),
                store.getName(),
                store.getDescription(),
                store.getStatus(),
                store.getBusinessStatus(),
                myRole
        );
    }
}

