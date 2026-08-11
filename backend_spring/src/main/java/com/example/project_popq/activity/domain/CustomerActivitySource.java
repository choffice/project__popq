package com.example.project_popq.activity.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.user.domain.User;
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
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "customer_activity_sources")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CustomerActivitySource extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "customer_activity_source_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id")
    private Store store;

    @Enumerated(EnumType.STRING)
    @Column(name = "activity_type", nullable = false, length = 30)
    private CustomerActivityType activityType;

    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", nullable = false, length = 30)
    private CustomerActivitySourceType sourceType;

    @Column(name = "source_key", nullable = false, length = 100)
    private String sourceKey;

    @Column(name = "activity_date", nullable = false)
    private LocalDate activityDate;

    @Column(name = "active", nullable = false)
    private boolean active;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    private CustomerActivitySource(
            User user,
            Store store,
            CustomerActivityType activityType,
            CustomerActivitySourceType sourceType,
            String sourceKey,
            LocalDate activityDate,
            Instant occurredAt
    ) {
        this.user = user;
        this.store = store;
        this.activityType = activityType;
        this.sourceType = sourceType;
        this.sourceKey = sourceKey;
        this.activityDate = activityDate;
        this.occurredAt = occurredAt;
        this.active = true;
    }

    public static CustomerActivitySource record(
            User user,
            Store store,
            CustomerActivityType activityType,
            CustomerActivitySourceType sourceType,
            String sourceKey,
            LocalDate activityDate,
            Instant occurredAt
    ) {
        return new CustomerActivitySource(
                user,
                store,
                activityType,
                sourceType,
                sourceKey,
                activityDate,
                occurredAt
        );
    }

    public boolean reactivate(Instant occurredAt, LocalDate activityDate) {
        if (active) {
            return false;
        }
        this.active = true;
        this.occurredAt = occurredAt;
        this.activityDate = activityDate;
        this.revokedAt = null;
        return true;
    }

    public boolean revoke(Instant revokedAt) {
        if (!active) {
            return false;
        }
        this.active = false;
        this.revokedAt = revokedAt;
        return true;
    }
}
