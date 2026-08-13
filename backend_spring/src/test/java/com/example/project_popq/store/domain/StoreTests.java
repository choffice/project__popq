package com.example.project_popq.store.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalTime;
import org.junit.jupiter.api.Test;

class StoreTests {

    @Test
    void manualOpenStatusAcceptsOrdersRegardlessOfGuideHours() {
        Store store = Store.create(StoreType.LOCAL_STORE, "수동 영업 테스트", null);
        store.updateOperatingPolicy(
                LocalTime.of(23, 0),
                LocalTime.of(23, 1),
                "MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY,SUNDAY",
                true,
                true,
                true
        );

        store.changeBusinessStatus(BusinessStatus.OPEN);

        assertThat(store.isOrderAccepting()).isTrue();
    }

    @Test
    void preparingOrPausedStoreDoesNotAcceptOrders() {
        Store store = Store.create(StoreType.LOCAL_STORE, "주문 중지 테스트", null);

        assertThat(store.isOrderAccepting()).isFalse();

        store.changeBusinessStatus(BusinessStatus.OPEN);
        store.updateOperatingPolicy(null, null, null, true, true, false);

        assertThat(store.isOrderAccepting()).isFalse();
    }

    @Test
    void businessStatusOnlyContainsPreparingAndOpen() {
        assertThat(BusinessStatus.values())
                .containsExactly(BusinessStatus.PRE_OPEN, BusinessStatus.OPEN);
    }
}
