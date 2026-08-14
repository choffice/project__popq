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

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

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

    @Column(name = "event_name", length = 150)
    private String eventName;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "description", length = 1000)
    private String description;

    @Column(name = "address", length = 255)
    private String address;

    @Column(name = "detail_address", length = 255)
    private String detailAddress;

    @Column(name = "representative_category", length = 50)
    private String representativeCategory;

    @Column(name = "image_url", length = 1000)
    private String imageUrl;

    @Column(name = "phone", length = 30)
    private String phone;

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "open_time")
    private LocalTime openTime;

    @Column(name = "close_time")
    private LocalTime closeTime;

    @Column(name = "operation_start_date")
    private LocalDate operationStartDate;

    @Column(name = "operation_end_date")
    private LocalDate operationEndDate;

    @Column(name = "closed_days", length = 100)
    private String closedDays;

    @Column(name = "takeout_available", nullable = false)
    private boolean takeoutAvailable = true;

    @Column(name = "dine_in_available", nullable = false)
    private boolean dineInAvailable = true;

    @Column(name = "order_accepting_enabled", nullable = false)
    private boolean orderAcceptingEnabled = true;

    @Column(name = "default_preparation_minutes")
    private Integer defaultPreparationMinutes;

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
        this.takeoutAvailable = true;
        this.dineInAvailable = true;
        this.orderAcceptingEnabled = true;
    }

    public static Store create(
            StoreType storeType,
            String name,
            String description
    ) {
        return new Store(storeType, name, description);
    }

    public void changeStoreType(StoreType storeType) {
        this.storeType = storeType;
    }

    public void updateEventName(String eventName) {
        this.eventName = eventName;
    }

    public void updateDiscoveryProfile(
            String address,
            BigDecimal latitude,
            BigDecimal longitude
    ) {
        this.address = address;
        this.latitude = latitude;
        this.longitude = longitude;
    }

    public void updateSellerProfile(
            String name,
            String description,
            String address,
            BigDecimal latitude,
            BigDecimal longitude
    ) {
        this.name = name;
        this.description = description;
        updateDiscoveryProfile(address, latitude, longitude);
    }

    public void updateBusinessProfile(
            String representativeCategory,
            String detailAddress,
            String imageUrl,
            String phone
    ) {
        this.representativeCategory = representativeCategory;
        this.detailAddress = detailAddress;
        this.imageUrl = imageUrl;
        this.phone = phone;
    }

    public void updateOperatingPolicy(
            LocalTime openTime,
            LocalTime closeTime,
            String closedDays,
            boolean takeoutAvailable,
            boolean dineInAvailable,
            boolean orderAcceptingEnabled
    ) {
        this.openTime = openTime;
        this.closeTime = closeTime;
        this.closedDays = closedDays;
        this.takeoutAvailable = takeoutAvailable;
        this.dineInAvailable = dineInAvailable;
        this.orderAcceptingEnabled = orderAcceptingEnabled;
    }

    public void updateOperationPeriod(
            LocalDate operationStartDate,
            LocalDate operationEndDate
    ) {
        this.operationStartDate = operationStartDate;
        this.operationEndDate = operationEndDate;
    }

    public void changeBusinessStatus(BusinessStatus businessStatus) {
        this.businessStatus = businessStatus;
    }

    public void changeStatus(StoreStatus status) {
        this.status = status;
    }

    public void changeDefaultPreparationMinutes(Integer minutes) {
        this.defaultPreparationMinutes = minutes;
    }

    public void suspend() {
        this.status = StoreStatus.SUSPENDED;
        this.businessStatus = BusinessStatus.PRE_OPEN;
    }

    public void reopen() {
        this.status = StoreStatus.ACTIVE;
        this.businessStatus = BusinessStatus.PRE_OPEN;
    }

    public boolean isActive() {
        return status == StoreStatus.ACTIVE;
    }

    public boolean isOpen() {
        return isActive() && businessStatus == BusinessStatus.OPEN;
    }

    public boolean isOrderAccepting() {
        return isOpen() && orderAcceptingEnabled;
    }
}
