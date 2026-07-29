package com.example.project_popq.qr.dto;

import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreTable;
import com.example.project_popq.store.domain.StoreType;
import java.time.Instant;

public record QrContextResponse(
        Long storeId,
        String storeName,
        StoreType storeType,
        BusinessStatus businessStatus,
        Long storeTableId,
        String tableName,
        Instant sessionExpiresAt
) {
    public static QrContextResponse of(QrCode qrCode, Instant sessionExpiresAt) {
        Store store = qrCode.getStore();
        StoreTable table = qrCode.getStoreTable();
        return new QrContextResponse(
                store.getId(),
                store.getName(),
                store.getStoreType(),
                store.getBusinessStatus(),
                table == null ? null : table.getId(),
                table == null ? null : table.getName(),
                sessionExpiresAt
        );
    }
}

