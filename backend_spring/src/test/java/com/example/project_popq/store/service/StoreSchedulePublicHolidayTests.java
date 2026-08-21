package com.example.project_popq.store.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreBusinessHour;
import com.example.project_popq.store.domain.StoreClosureRule;
import com.example.project_popq.store.domain.StoreClosureRuleType;
import com.example.project_popq.store.dto.StoreScheduleResponse;
import com.example.project_popq.store.repository.StoreBusinessHourRepository;
import com.example.project_popq.store.repository.StoreClosureRuleRepository;
import com.example.project_popq.store.repository.StoreScheduleExceptionRepository;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class StoreSchedulePublicHolidayTests {

    @Mock private StoreBusinessHourRepository businessHourRepository;
    @Mock private StoreClosureRuleRepository closureRuleRepository;
    @Mock private StoreScheduleExceptionRepository exceptionRepository;
    @Mock private PublicHolidayService publicHolidayService;
    @Mock private Store holidayStore;
    @Mock private Store ordinaryStore;

    private StoreScheduleService service;

    @BeforeEach
    void setUp() {
        service = new StoreScheduleService(
                businessHourRepository,
                closureRuleRepository,
                exceptionRepository,
                publicHolidayService
        );
    }

    @Test
    void bulkEvaluationLoadsHolidayDataOnceAndAddsItToEverySchedule() {
        LocalDate date = LocalDate.of(2026, 8, 15);
        Instant instant = Instant.parse("2026-08-15T03:00:00Z");
        when(holidayStore.getId()).thenReturn(1L);
        when(ordinaryStore.getId()).thenReturn(2L);

        StoreBusinessHour holidayHours = StoreBusinessHour.create(
                holidayStore,
                DayOfWeek.SATURDAY,
                false,
                true,
                null,
                null
        );
        StoreBusinessHour ordinaryHours = StoreBusinessHour.create(
                ordinaryStore,
                DayOfWeek.SATURDAY,
                false,
                true,
                null,
                null
        );
        StoreClosureRule publicHolidayRule = StoreClosureRule.create(
                holidayStore,
                StoreClosureRuleType.PUBLIC_HOLIDAY,
                null,
                null
        );

        when(businessHourRepository.findAllByStoreIdIn(List.of(1L, 2L)))
                .thenReturn(List.of(holidayHours, ordinaryHours));
        when(closureRuleRepository.findAllByStoreIdIn(List.of(1L, 2L)))
                .thenReturn(List.of(publicHolidayRule));
        when(exceptionRepository
                .findAllByStoreIdInAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
                        List.of(1L, 2L),
                        date,
                        date.minusDays(1)
                )).thenReturn(List.of());
        when(publicHolidayService.evaluate(date)).thenReturn(
                new PublicHolidayService.Evaluation(
                        true,
                        date,
                        true,
                        "광복절"
                )
        );

        Map<Long, StoreScheduleResponse> schedules =
                service.findAllForEvaluation(
                        List.of(holidayStore, ordinaryStore),
                        instant
                );

        verify(publicHolidayService).evaluate(date);
        assertThat(schedules.get(1L).closureRules())
                .extracting(StoreScheduleResponse.ClosureRule::ruleType)
                .containsExactly(StoreClosureRuleType.PUBLIC_HOLIDAY);
        assertThat(schedules.get(2L).closureRules()).isEmpty();
        assertThat(schedules.values())
                .allSatisfy(schedule -> {
                    assertThat(schedule.publicHolidayAutoCalculationAvailable())
                            .isTrue();
                    assertThat(schedule.publicHolidayEvaluationDate())
                            .isEqualTo(date);
                    assertThat(schedule.publicHoliday()).isTrue();
                    assertThat(schedule.publicHolidayName()).isEqualTo("광복절");
                });
    }

    @Test
    void missingApiKeyKeepsExistingScheduleResponseAvailable() {
        when(holidayStore.getId()).thenReturn(1L);
        StoreBusinessHour hours = StoreBusinessHour.create(
                holidayStore,
                DayOfWeek.THURSDAY,
                false,
                true,
                null,
                null
        );
        when(businessHourRepository.findAllByStoreIdOrderByDayOfWeekAsc(1L))
                .thenReturn(List.of(hours));
        when(closureRuleRepository.findAllByStoreIdOrderByIdAsc(1L))
                .thenReturn(List.of());
        when(exceptionRepository.findAllByStoreIdOrderByStartDateAscIdAsc(1L))
                .thenReturn(List.of());

        PublicHolidayService noKeyService = new PublicHolidayService(
                "",
                Clock.fixed(
                        Instant.parse("2026-08-20T00:00:00Z"),
                        ZoneOffset.UTC
                ),
                year -> {
                    throw new AssertionError("API must not be called");
                }
        );
        StoreScheduleService scheduleService = new StoreScheduleService(
                businessHourRepository,
                closureRuleRepository,
                exceptionRepository,
                noKeyService
        );

        StoreScheduleResponse response = scheduleService.find(holidayStore);

        assertThat(response.businessHours()).hasSize(1);
        assertThat(response.businessHours().get(0).open24Hours()).isTrue();
        assertThat(response.publicHolidayAutoCalculationAvailable()).isFalse();
        assertThat(response.publicHoliday()).isNull();
    }
}
