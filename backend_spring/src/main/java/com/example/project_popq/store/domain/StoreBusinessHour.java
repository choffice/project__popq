package com.example.project_popq.store.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
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
import java.time.DayOfWeek;
import java.time.LocalTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "store_business_hours")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreBusinessHour extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_business_hour_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Enumerated(EnumType.STRING)
    @Column(name = "day_of_week", nullable = false, length = 20)
    private DayOfWeek dayOfWeek;

    @Column(name = "is_closed", nullable = false)
    private boolean closed;

    @Column(name = "is_24_hours", nullable = false)
    private boolean open24Hours;

    @Column(name = "open_time")
    private LocalTime openTime;

    @Column(name = "close_time")
    private LocalTime closeTime;

    public static StoreBusinessHour create(
            Store store,
            DayOfWeek dayOfWeek,
            boolean closed,
            boolean open24Hours,
            LocalTime openTime,
            LocalTime closeTime
    ) {
        StoreBusinessHour value = new StoreBusinessHour();
        value.store = store;
        value.dayOfWeek = dayOfWeek;
        value.closed = closed;
        value.open24Hours = open24Hours;
        value.openTime = openTime;
        value.closeTime = closeTime;
        return value;
    }
}
