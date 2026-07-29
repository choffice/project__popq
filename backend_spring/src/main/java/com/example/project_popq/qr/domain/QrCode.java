package com.example.project_popq.qr.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreTable;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "qr_codes")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QrCode extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "qr_code_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_table_id")
    private StoreTable storeTable;

    @Column(name = "token_hash", nullable = false, length = 64, unique = true)
    private String tokenHash;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private QrCodeStatus status;

    @Column(name = "expires_at")
    private Instant expiresAt;

    private QrCode(
            Store store,
            StoreTable storeTable,
            String tokenHash,
            Instant expiresAt
    ) {
        this.store = store;
        this.storeTable = storeTable;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
        this.status = QrCodeStatus.ACTIVE;
    }

    public static QrCode issue(
            Store store,
            StoreTable storeTable,
            String tokenHash,
            Instant expiresAt
    ) {
        return new QrCode(store, storeTable, tokenHash, expiresAt);
    }

    public void revoke() {
        status = QrCodeStatus.REVOKED;
    }

    public void deactivate() {
        if (status == QrCodeStatus.ACTIVE) {
            status = QrCodeStatus.INACTIVE;
        }
    }

    public boolean activate() {
        if (status == QrCodeStatus.REVOKED) {
            return false;
        }
        status = QrCodeStatus.ACTIVE;
        return true;
    }

    public boolean isExpired(Instant now) {
        return expiresAt != null && now.isAfter(expiresAt);
    }
}
