package com.example.project_popq.qr.dto;

import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.domain.QrCodeStatus;
import java.time.Instant;

public record QrDetailResponse(
        Long qrCodeId,
        Long storeId,
        Long storeTableId,
        String tableName,
        QrCodeStatus status,
        Instant expiresAt,
        Instant createdAt,
        String publicUrl
) {
    public static QrDetailResponse of(QrCode qrCode, String publicUrl) {
        return new QrDetailResponse(
                qrCode.getId(),
                qrCode.getStore().getId(),
                qrCode.getStoreTable() == null
                        ? null
                        : qrCode.getStoreTable().getId(),
                qrCode.getStoreTable() == null
                        ? null
                        : qrCode.getStoreTable().getName(),
                qrCode.getStatus(),
                qrCode.getExpiresAt(),
                qrCode.getCreatedAt(),
                publicUrl
        );
    }
}
