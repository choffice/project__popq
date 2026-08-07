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
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "store_schedule_exceptions")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreScheduleException extends BaseTimeEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_schedule_exception_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "exception_type", nullable = false, length = 30)
    private StoreScheduleExceptionType exceptionType;

    @Column(name = "memo", length = 255)
    private String memo;

    public static StoreScheduleException create(
            Store store,
            LocalDate startDate,
            LocalDate endDate,
            StoreScheduleExceptionType exceptionType,
            String memo
    ) {
        StoreScheduleException value = new StoreScheduleException();
        value.store = store;
        value.startDate = startDate;
        value.endDate = endDate;
        value.exceptionType = exceptionType;
        value.memo = memo;
        return value;
    }
}
