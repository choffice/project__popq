package com.example.project_popq.store.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

class PublicHolidayServiceTests {

    private static final Clock FIXED_CLOCK = Clock.fixed(
            Instant.parse("2026-08-14T00:00:00Z"),
            ZoneOffset.UTC
    );

    @Test
    void missingApiKeyKeepsHolidayCalculationUnavailable() {
        PublicHolidayService service = new PublicHolidayService(
                "",
                FIXED_CLOCK,
                year -> {
                    throw new AssertionError("API must not be called");
                }
        );

        PublicHolidayService.Evaluation evaluation =
                service.evaluate(LocalDate.of(2026, 8, 15));

        assertThat(evaluation.available()).isFalse();
        assertThat(evaluation.publicHoliday()).isFalse();
        assertThat(evaluation.evaluationDate())
                .isEqualTo(LocalDate.of(2026, 8, 15));
    }

    @Test
    void acceptsPortalGeneralKeyInEitherEncodedOrDecodedForm() {
        assertThat(PublicHolidayService.normalizeServiceKey("abc%2Bdef%2Fghi%3D"))
                .isEqualTo("abc+def/ghi=");
        assertThat(PublicHolidayService.normalizeServiceKey("abc+def/ghi="))
                .isEqualTo("abc+def/ghi=");
    }

    @Test
    void malformedPercentEncodingDoesNotPreventServiceStartup() {
        assertThat(PublicHolidayService.normalizeServiceKey("abc%not-encoded"))
                .isEqualTo("abc%not-encoded");
    }

    @Test
    void parsesOnlyItemsMarkedAsHolidays() throws Exception {
        Map<LocalDate, String> holidays =
                PublicHolidayService.parseHolidayXml(successResponse());

        assertThat(holidays)
                .containsEntry(LocalDate.of(2026, 8, 15), "광복절")
                .doesNotContainKey(LocalDate.of(2026, 8, 14));
    }

    @Test
    void cachesOneSuccessfulResponsePerYear() {
        AtomicInteger calls = new AtomicInteger();
        PublicHolidayService service = new PublicHolidayService(
                "decoded-service-key",
                FIXED_CLOCK,
                year -> {
                    calls.incrementAndGet();
                    return successResponse();
                }
        );

        PublicHolidayService.Evaluation holiday =
                service.evaluate(LocalDate.of(2026, 8, 15));
        PublicHolidayService.Evaluation ordinaryDay =
                service.evaluate(LocalDate.of(2026, 8, 16));

        assertThat(calls).hasValue(1);
        assertThat(holiday.available()).isTrue();
        assertThat(holiday.publicHoliday()).isTrue();
        assertThat(holiday.holidayName()).isEqualTo("광복절");
        assertThat(ordinaryDay.available()).isTrue();
        assertThat(ordinaryDay.publicHoliday()).isFalse();
    }

    @Test
    void externalFailureReturnsUnavailableInsteadOfThrowing() {
        PublicHolidayService service = new PublicHolidayService(
                "decoded-service-key",
                FIXED_CLOCK,
                year -> {
                    throw new IllegalStateException("temporary failure");
                }
        );

        PublicHolidayService.Evaluation evaluation =
                service.evaluate(LocalDate.of(2026, 8, 15));

        assertThat(evaluation.available()).isFalse();
        assertThat(evaluation.publicHoliday()).isFalse();
    }

    @Test
    void refreshFailureKeepsPreviouslyCachedHolidayData() {
        MutableClock clock = new MutableClock(
                Instant.parse("2026-08-14T00:00:00Z")
        );
        AtomicInteger calls = new AtomicInteger();
        PublicHolidayService service = new PublicHolidayService(
                "decoded-service-key",
                clock,
                year -> {
                    if (calls.incrementAndGet() == 1) {
                        return successResponse();
                    }
                    throw new IllegalStateException("refresh failure");
                }
        );

        assertThat(service.evaluate(LocalDate.of(2026, 8, 15)).publicHoliday())
                .isTrue();
        clock.advance(Duration.ofHours(25));

        PublicHolidayService.Evaluation evaluation =
                service.evaluate(LocalDate.of(2026, 8, 15));

        assertThat(calls).hasValue(2);
        assertThat(evaluation.available()).isTrue();
        assertThat(evaluation.publicHoliday()).isTrue();
        assertThat(evaluation.holidayName()).isEqualTo("광복절");
    }

    private static String successResponse() {
        return """
                <?xml version="1.0" encoding="UTF-8"?>
                <response>
                  <header><resultCode>00</resultCode><resultMsg>OK</resultMsg></header>
                  <body>
                    <items>
                      <item>
                        <dateName>광복절</dateName>
                        <isHoliday>Y</isHoliday>
                        <locdate>20260815</locdate>
                      </item>
                      <item>
                        <dateName>기념일</dateName>
                        <isHoliday>N</isHoliday>
                        <locdate>20260814</locdate>
                      </item>
                    </items>
                    <numOfRows>100</numOfRows><pageNo>1</pageNo><totalCount>2</totalCount>
                  </body>
                </response>
                """;
    }

    private static final class MutableClock extends Clock {
        private Instant instant;

        private MutableClock(Instant instant) {
            this.instant = instant;
        }

        private void advance(Duration duration) {
            instant = instant.plus(duration);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return instant;
        }
    }
}
