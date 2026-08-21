package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.StoreBusinessHour;
import com.example.project_popq.store.domain.StoreClosureRule;
import com.example.project_popq.store.domain.StoreClosureRuleType;
import com.example.project_popq.store.domain.StoreScheduleException;
import com.example.project_popq.store.domain.StoreScheduleExceptionType;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record StoreScheduleResponse(
        List<BusinessHour> businessHours,
        List<ClosureRule> closureRules,
        List<ScheduleException> scheduleExceptions,
        boolean publicHolidayAutoCalculationAvailable,
        LocalDate publicHolidayEvaluationDate,
        Boolean publicHoliday,
        String publicHolidayName
) {
    public StoreScheduleResponse(
            List<BusinessHour> businessHours,
            List<ClosureRule> closureRules,
            List<ScheduleException> scheduleExceptions,
            boolean publicHolidayAutoCalculationAvailable
    ) {
        this(
                businessHours,
                closureRules,
                scheduleExceptions,
                publicHolidayAutoCalculationAvailable,
                null,
                null,
                null
        );
    }

    public record BusinessHour(
            DayOfWeek dayOfWeek,
            boolean closed,
            boolean open24Hours,
            LocalTime openTime,
            LocalTime closeTime
    ) {
        public static BusinessHour from(StoreBusinessHour value) {
            return new BusinessHour(
                    value.getDayOfWeek(), value.isClosed(),
                    value.isOpen24Hours(), value.getOpenTime(), value.getCloseTime()
            );
        }
    }

    public record ClosureRule(
            StoreClosureRuleType ruleType,
            Integer weekOfMonth,
            DayOfWeek dayOfWeek
    ) {
        public static ClosureRule from(StoreClosureRule value) {
            return new ClosureRule(
                    value.getRuleType(), value.getWeekOfMonth(), value.getDayOfWeek()
            );
        }
    }

    public record ScheduleException(
            LocalDate startDate,
            LocalDate endDate,
            StoreScheduleExceptionType exceptionType,
            String memo
    ) {
        public static ScheduleException from(StoreScheduleException value) {
            return new ScheduleException(
                    value.getStartDate(), value.getEndDate(),
                    value.getExceptionType(), value.getMemo()
            );
        }
    }
}
