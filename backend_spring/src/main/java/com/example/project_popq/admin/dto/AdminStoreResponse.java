package com.example.project_popq.admin.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;
import java.time.Instant;

public record AdminStoreResponse(
        Long storeId,
        StoreType storeType,
        String name,
        StoreStatus status,
        BusinessStatus businessStatus,
        Instant createdAt
) {
    public static AdminStoreResponse from(Store store) {
        return new AdminStoreResponse(
                store.getId(),
                store.getStoreType(),
                store.getName(),
                store.getStatus(),
                store.getBusinessStatus(),
                store.getCreatedAt()
        );
    }
}
