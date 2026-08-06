package com.example.project_popq.store.service;

import com.example.project_popq.store.domain.Store;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

@Component
public class StoreOperatingHoursPolicy {

    public static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Seoul");

    public boolean isWithinOperatingHours(Store store, Instant instant) {
        LocalTime openTime = store.getOpenTime();
        LocalTime closeTime = store.getCloseTime();
        if (openTime == null || closeTime == null) {
            return false;
        }

        ZonedDateTime now = instant.atZone(BUSINESS_ZONE);
        LocalTime time = now.toLocalTime();
        LocalDate serviceDate = now.toLocalDate();

        if (openTime.equals(closeTime)) {
            return !isClosed(store, serviceDate.getDayOfWeek());
        }
        if (openTime.isBefore(closeTime)) {
            return !isClosed(store, serviceDate.getDayOfWeek())
                    && !time.isBefore(openTime)
                    && time.isBefore(closeTime);
        }
        if (!time.isBefore(openTime)) {
            return !isClosed(store, serviceDate.getDayOfWeek());
        }
        if (time.isBefore(closeTime)) {
            return !isClosed(store, serviceDate.minusDays(1).getDayOfWeek());
        }
        return false;
    }

    public boolean isEffectivelyOrderAccepting(Store store, Instant instant) {
        return store.isOpen()
                && store.isOrderAcceptingEnabled()
                && isWithinOperatingHours(store, instant);
    }

    private boolean isClosed(Store store, DayOfWeek dayOfWeek) {
        String closedDays = store.getClosedDays();
        if (closedDays == null || closedDays.isBlank()) {
            return false;
        }
        Set<String> values = Arrays.stream(closedDays.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .collect(Collectors.toSet());
        return values.contains(dayOfWeek.name());
    }
}
