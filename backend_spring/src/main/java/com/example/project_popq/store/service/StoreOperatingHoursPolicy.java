package com.example.project_popq.store.service;

import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreClosureRuleType;
import com.example.project_popq.store.domain.StoreScheduleExceptionType;
import com.example.project_popq.store.dto.StoreScheduleResponse;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class StoreOperatingHoursPolicy {

    public static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Seoul");
    private final StoreScheduleService scheduleService;

    public boolean isWithinOperatingHours(Store store, Instant instant) {
        StoreScheduleResponse schedule = scheduleService.find(store);
        return isWithinOperatingHours(store, instant, schedule);
    }

    public boolean isWithinOperatingHours(
            Store store,
            Instant instant,
            StoreScheduleResponse schedule
    ) {
        ZonedDateTime now = instant.atZone(BUSINESS_ZONE);
        LocalTime time = now.toLocalTime();
        LocalDate today = now.toLocalDate();
        if (isClosedOn(schedule, today)) return false;

        StoreScheduleResponse.BusinessHour todayHours =
                findHours(schedule, today.getDayOfWeek());
        if (todayHours != null && !todayHours.closed()) {
            if (todayHours.open24Hours()) return true;
            if (containsSameDay(todayHours, time)) return true;
        }

        LocalDate yesterday = today.minusDays(1);
        if (isClosedOn(schedule, yesterday)) return false;
        StoreScheduleResponse.BusinessHour yesterdayHours =
                findHours(schedule, yesterday.getDayOfWeek());
        return yesterdayHours != null
                && !yesterdayHours.closed()
                && !yesterdayHours.open24Hours()
                && crossesMidnight(yesterdayHours)
                && time.isBefore(yesterdayHours.closeTime());
    }

    public boolean isEffectivelyOrderAccepting(Store store, Instant instant) {
        return store.isOpen()
                && store.isOrderAcceptingEnabled()
                && isWithinOperatingHours(store, instant);
    }

    private boolean containsSameDay(
            StoreScheduleResponse.BusinessHour hours,
            LocalTime time
    ) {
        if (hours.openTime() == null || hours.closeTime() == null) return false;
        if (hours.openTime().isBefore(hours.closeTime())) {
            return !time.isBefore(hours.openTime()) && time.isBefore(hours.closeTime());
        }
        return hours.openTime().isAfter(hours.closeTime())
                && !time.isBefore(hours.openTime());
    }

    private boolean crossesMidnight(StoreScheduleResponse.BusinessHour hours) {
        return hours.openTime() != null && hours.closeTime() != null
                && hours.openTime().isAfter(hours.closeTime());
    }

    private StoreScheduleResponse.BusinessHour findHours(
            StoreScheduleResponse schedule,
            DayOfWeek day
    ) {
        return schedule.businessHours().stream()
                .filter(value -> value.dayOfWeek() == day)
                .findFirst()
                .orElse(null);
    }

    private boolean isClosedOn(StoreScheduleResponse schedule, LocalDate date) {
        boolean exceptionClosed = schedule.scheduleExceptions().stream()
                .anyMatch(value -> value.exceptionType() == StoreScheduleExceptionType.CLOSED
                        && !date.isBefore(value.startDate())
                        && !date.isAfter(value.endDate()));
        if (exceptionClosed) return true;

        int weekOfMonth = ((date.getDayOfMonth() - 1) / 7) + 1;
        return schedule.closureRules().stream()
                .anyMatch(value -> value.ruleType() == StoreClosureRuleType.NTH_WEEKDAY
                        && value.dayOfWeek() == date.getDayOfWeek()
                        && value.weekOfMonth() != null
                        && value.weekOfMonth() == weekOfMonth);
    }
}
