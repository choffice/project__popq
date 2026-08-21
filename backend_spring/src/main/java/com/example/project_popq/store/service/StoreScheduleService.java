package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreBusinessHour;
import com.example.project_popq.store.domain.StoreClosureRule;
import com.example.project_popq.store.domain.StoreClosureRuleType;
import com.example.project_popq.store.domain.StoreScheduleException;
import com.example.project_popq.store.dto.StoreBusinessHourRequest;
import com.example.project_popq.store.dto.StoreClosureRuleRequest;
import com.example.project_popq.store.dto.StoreScheduleExceptionRequest;
import com.example.project_popq.store.dto.StoreScheduleRequest;
import com.example.project_popq.store.dto.StoreScheduleResponse;
import com.example.project_popq.store.repository.StoreBusinessHourRepository;
import com.example.project_popq.store.repository.StoreClosureRuleRepository;
import com.example.project_popq.store.repository.StoreScheduleExceptionRepository;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class StoreScheduleService {

    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Seoul");

    private final StoreBusinessHourRepository businessHourRepository;
    private final StoreClosureRuleRepository closureRuleRepository;
    private final StoreScheduleExceptionRepository exceptionRepository;
    private final PublicHolidayService publicHolidayService;

    public void createInitialSchedule(Store store, StoreScheduleRequest request) {
        if (request == null) {
            saveLegacyBusinessHours(store);
            return;
        }
        replace(store, request);
    }

    public void replace(Store store, StoreScheduleRequest request) {
        if (request == null) {
            return;
        }
        List<StoreBusinessHourRequest> hours = request.businessHours();
        validateBusinessHours(hours);
        validateClosureRules(request.closureRules());
        validateExceptions(request.scheduleExceptions());

        Long storeId = store.getId();
        businessHourRepository.deleteAllByStoreId(storeId);
        closureRuleRepository.deleteAllByStoreId(storeId);
        exceptionRepository.deleteAllByStoreId(storeId);
        businessHourRepository.flush();
        closureRuleRepository.flush();
        exceptionRepository.flush();

        businessHourRepository.saveAll(hours.stream()
                .map(value -> StoreBusinessHour.create(
                        store, value.dayOfWeek(), value.closed(),
                        value.open24Hours(), value.openTime(), value.closeTime()
                ))
                .toList());
        closureRuleRepository.saveAll(safe(request.closureRules()).stream()
                .map(value -> StoreClosureRule.create(
                        store, value.ruleType(), value.weekOfMonth(), value.dayOfWeek()
                ))
                .toList());
        exceptionRepository.saveAll(safe(request.scheduleExceptions()).stream()
                .map(value -> StoreScheduleException.create(
                        store, value.startDate(), value.endDate(),
                        value.exceptionType(), normalize(value.memo())
                ))
                .toList());
    }

    public StoreScheduleResponse find(Store store) {
        PublicHolidayService.Evaluation holidayEvaluation =
                publicHolidayService.evaluate(LocalDate.now(BUSINESS_ZONE));
        List<StoreBusinessHour> hours =
                businessHourRepository.findAllByStoreIdOrderByDayOfWeekAsc(store.getId());
        if (hours.isEmpty()) {
            return legacyResponse(store, holidayEvaluation);
        }
        return scheduleResponse(
                hours.stream()
                        .sorted((a, b) -> a.getDayOfWeek().compareTo(b.getDayOfWeek()))
                        .map(StoreScheduleResponse.BusinessHour::from).toList(),
                closureRuleRepository.findAllByStoreIdOrderByIdAsc(store.getId())
                        .stream().map(StoreScheduleResponse.ClosureRule::from).toList(),
                exceptionRepository.findAllByStoreIdOrderByStartDateAscIdAsc(store.getId())
                        .stream().map(StoreScheduleResponse.ScheduleException::from).toList(),
                holidayEvaluation
        );
    }

    public Map<Long, StoreScheduleResponse> findAllForEvaluation(
            List<Store> stores,
            Instant instant
    ) {
        if (stores.isEmpty()) return Map.of();
        List<Long> ids = stores.stream().map(Store::getId).toList();
        LocalDate today = instant.atZone(BUSINESS_ZONE).toLocalDate();
        PublicHolidayService.Evaluation holidayEvaluation =
                publicHolidayService.evaluate(today);
        Map<Long, List<StoreBusinessHour>> hours = businessHourRepository
                .findAllByStoreIdIn(ids).stream()
                .collect(Collectors.groupingBy(value -> value.getStore().getId()));
        Map<Long, List<StoreClosureRule>> rules = closureRuleRepository
                .findAllByStoreIdIn(ids).stream()
                .collect(Collectors.groupingBy(value -> value.getStore().getId()));
        Map<Long, List<StoreScheduleException>> exceptions = exceptionRepository
                .findAllByStoreIdInAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
                        ids, today, today.minusDays(1)
                ).stream()
                .collect(Collectors.groupingBy(value -> value.getStore().getId()));
        Map<Long, StoreScheduleResponse> result = new HashMap<>();
        for (Store store : stores) {
            List<StoreBusinessHour> storeHours = hours.getOrDefault(store.getId(), List.of());
            if (storeHours.isEmpty()) {
                result.put(store.getId(), legacyResponse(store, holidayEvaluation));
                continue;
            }
            result.put(store.getId(), scheduleResponse(
                    storeHours.stream()
                            .sorted((a, b) -> a.getDayOfWeek().compareTo(b.getDayOfWeek()))
                            .map(StoreScheduleResponse.BusinessHour::from).toList(),
                    rules.getOrDefault(store.getId(), List.of()).stream()
                            .map(StoreScheduleResponse.ClosureRule::from).toList(),
                    exceptions.getOrDefault(store.getId(), List.of()).stream()
                            .sorted((a, b) -> a.getStartDate().compareTo(b.getStartDate()))
                            .map(StoreScheduleResponse.ScheduleException::from).toList(),
                    holidayEvaluation
            ));
        }
        return Map.copyOf(result);
    }

    private void saveLegacyBusinessHours(Store store) {
        Set<String> closed = legacyClosedDays(store);
        businessHourRepository.saveAll(EnumSet.allOf(DayOfWeek.class).stream()
                .map(day -> {
                    boolean dayClosed = closed.contains(day.name());
                    boolean open24Hours = !dayClosed
                            && store.getOpenTime() != null
                            && store.getOpenTime().equals(store.getCloseTime());
                    return StoreBusinessHour.create(
                            store, day, dayClosed, open24Hours,
                            dayClosed || open24Hours ? null : store.getOpenTime(),
                            dayClosed || open24Hours ? null : store.getCloseTime()
                    );
                })
                .toList());
    }

    private StoreScheduleResponse legacyResponse(
            Store store,
            PublicHolidayService.Evaluation holidayEvaluation
    ) {
        Set<String> closed = legacyClosedDays(store);
        List<StoreScheduleResponse.BusinessHour> hours =
                EnumSet.allOf(DayOfWeek.class).stream()
                        .map(day -> new StoreScheduleResponse.BusinessHour(
                                day,
                                closed.contains(day.name()),
                                store.getOpenTime() != null
                                        && store.getOpenTime().equals(store.getCloseTime()),
                                closed.contains(day.name()) ? null : store.getOpenTime(),
                                closed.contains(day.name()) ? null : store.getCloseTime()
                        ))
                        .toList();
        return scheduleResponse(
                hours,
                List.of(),
                List.of(),
                holidayEvaluation
        );
    }

    private StoreScheduleResponse scheduleResponse(
            List<StoreScheduleResponse.BusinessHour> hours,
            List<StoreScheduleResponse.ClosureRule> rules,
            List<StoreScheduleResponse.ScheduleException> exceptions,
            PublicHolidayService.Evaluation holidayEvaluation
    ) {
        return new StoreScheduleResponse(
                hours,
                rules,
                exceptions,
                holidayEvaluation.available(),
                holidayEvaluation.evaluationDate(),
                holidayEvaluation.available()
                        ? holidayEvaluation.publicHoliday()
                        : null,
                holidayEvaluation.holidayName()
        );
    }

    private void validateBusinessHours(List<StoreBusinessHourRequest> values) {
        if (values == null || values.size() != 7) invalid();
        Set<DayOfWeek> days = EnumSet.noneOf(DayOfWeek.class);
        for (StoreBusinessHourRequest value : values) {
            if (value == null || value.dayOfWeek() == null || !days.add(value.dayOfWeek())) {
                invalid();
            }
            if (value.closed() && value.open24Hours()) invalid();
            if (!value.closed() && !value.open24Hours()
                    && (value.openTime() == null || value.closeTime() == null
                    || value.openTime().equals(value.closeTime()))) {
                invalid();
            }
        }
        if (!days.equals(EnumSet.allOf(DayOfWeek.class))) invalid();
    }

    private void validateClosureRules(List<StoreClosureRuleRequest> values) {
        for (StoreClosureRuleRequest value : safe(values)) {
            if (value == null || value.ruleType() == null) invalid();
            if (value.ruleType() == StoreClosureRuleType.NTH_WEEKDAY
                    && (value.dayOfWeek() == null || value.weekOfMonth() == null
                    || value.weekOfMonth() < 1 || value.weekOfMonth() > 5)) {
                invalid();
            }
            if (value.ruleType() == StoreClosureRuleType.PUBLIC_HOLIDAY
                    && (value.dayOfWeek() != null || value.weekOfMonth() != null)) {
                invalid();
            }
        }
    }

    private void validateExceptions(List<StoreScheduleExceptionRequest> values) {
        for (StoreScheduleExceptionRequest value : safe(values)) {
            if (value == null || value.startDate() == null || value.endDate() == null
                    || value.exceptionType() == null
                    || value.startDate().isAfter(value.endDate())) {
                invalid();
            }
        }
    }

    private Set<String> legacyClosedDays(Store store) {
        if (store.getClosedDays() == null || store.getClosedDays().isBlank()) {
            return Set.of();
        }
        return java.util.Arrays.stream(store.getClosedDays().split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .collect(Collectors.toSet());
    }

    private <T> List<T> safe(List<T> values) {
        return values == null ? List.of() : values;
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private void invalid() {
        throw new BusinessException(ErrorCode.INVALID_REQUEST);
    }
}
