package com.example.project_popq.product.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "product_availability")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ProductAvailability extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "product_availability_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false, unique = true)
    private Product product;

    @Column(name = "sold_out", nullable = false)
    private boolean soldOut;

    @Column(name = "sales_start_at")
    private Instant salesStartAt;

    @Column(name = "sales_end_at")
    private Instant salesEndAt;

    @Column(name = "qr_web_enabled", nullable = false)
    private boolean qrWebEnabled;

    @Column(name = "customer_app_enabled", nullable = false)
    private boolean customerAppEnabled;

    private ProductAvailability(Product product) {
        this.product = product;
        this.soldOut = false;
        this.qrWebEnabled = true;
        this.customerAppEnabled = true;
    }

    public static ProductAvailability createDefault(Product product) {
        return new ProductAvailability(product);
    }

    public void update(
            boolean soldOut,
            Instant salesStartAt,
            Instant salesEndAt,
            boolean qrWebEnabled,
            boolean customerAppEnabled
    ) {
        this.soldOut = soldOut;
        this.salesStartAt = salesStartAt;
        this.salesEndAt = salesEndAt;
        this.qrWebEnabled = qrWebEnabled;
        this.customerAppEnabled = customerAppEnabled;
    }

    public boolean isAvailableForQr(Instant now) {
        return !soldOut && isVisibleForQr(now);
    }

    public boolean isVisibleForQr(Instant now) {
        if (!qrWebEnabled) {
            return false;
        }
        if (salesStartAt != null && now.isBefore(salesStartAt)) {
            return false;
        }
        return salesEndAt == null || !now.isAfter(salesEndAt);
    }

    public boolean isAvailableForCustomerApp(Instant now) {
        return !soldOut && isVisibleForCustomerApp(now);
    }

    public boolean isVisibleForCustomerApp(Instant now) {
        if (!customerAppEnabled) {
            return false;
        }
        if (salesStartAt != null && now.isBefore(salesStartAt)) {
            return false;
        }
        return salesEndAt == null || !now.isAfter(salesEndAt);
    }
}
