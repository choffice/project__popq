package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.StoreTable;
import com.example.project_popq.store.domain.StoreTableStatus;

public record StoreTableResponse(
        Long storeTableId,
        String tableCode,
        String name,
        StoreTableStatus status
) {
    public static StoreTableResponse from(StoreTable storeTable) {
        return new StoreTableResponse(
                storeTable.getId(),
                storeTable.getTableCode(),
                storeTable.getName(),
                storeTable.getStatus()
        );
    }
}

