package com.example.project_popq.qr.dto;

import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.domain.QrCodeStatus;
import java.time.Instant;

public record QrSummaryResponse(
        Long qrCodeId,
        Long storeTableId,
        String tableName,
        QrCodeStatus status,
        Instant expiresAt,
        Instant createdAt,
        boolean recoverable,
        boolean archived
) {
    public static QrSummaryResponse from(QrCode qrCode) {
        return new QrSummaryResponse(
                qrCode.getId(),
                qrCode.getStoreTable() == null
                        ? null
                        : qrCode.getStoreTable().getId(),
                qrCode.getStoreTable() == null
                        ? null
                        : qrCode.getStoreTable().getName(),
                qrCode.getStatus(),
                qrCode.getExpiresAt(),
                qrCode.getCreatedAt(),
                qrCode.isRecoverable(),
                qrCode.isArchived()
        );
    }
}
