package com.example.project_popq.store.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "stores")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Store extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "store_type", nullable = false, length = 30)
    private StoreType storeType;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "description", length = 1000)
    private String description;

    @Column(name = "address", length = 255)
    private String address;

    @Column(name = "latitude", precision = 10, scale = 7)
    private java.math.BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private java.math.BigDecimal longitude;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private StoreStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "business_status", nullable = false, length = 30)
    private BusinessStatus businessStatus;

    private Store(StoreType storeType, String name, String description) {
        this.storeType = storeType;
        this.name = name;
        this.description = description;
        this.status = StoreStatus.ACTIVE;
        this.businessStatus = BusinessStatus.PRE_OPEN;
    }

    public static Store create(StoreType storeType, String name, String description) {
        return new Store(storeType, name, description);
    }

    public void updateDiscoveryProfile(
            String address,
            java.math.BigDecimal latitude,
            java.math.BigDecimal longitude
    ) {
        this.address = address;
        this.latitude = latitude;
        this.longitude = longitude;
    }

    public void changeBusinessStatus(BusinessStatus businessStatus) {
        this.businessStatus = businessStatus;
    }

    public void changeStatus(StoreStatus status) {
        this.status = status;
    }

    public boolean isActive() {
        return status == StoreStatus.ACTIVE;
    }

    public boolean isOpen() {
        return isActive() && businessStatus == BusinessStatus.OPEN;
    }
}
