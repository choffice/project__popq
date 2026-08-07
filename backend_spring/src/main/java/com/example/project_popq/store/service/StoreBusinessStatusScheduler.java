package com.example.project_popq.store.service;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.dto.StoreScheduleResponse;
import com.example.project_popq.store.repository.StoreRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class StoreBusinessStatusScheduler {

    private final StoreRepository storeRepository;
    private final StoreOperatingHoursPolicy operatingHoursPolicy;
    private final StoreScheduleService storeScheduleService;

    @Scheduled(fixedDelayString = "${popq.store.closure-check-ms:60000}")
    @Transactional
    public void closeStoresOutsideOperatingHours() {
        Instant now = Instant.now();
        List<Store> stores = storeRepository.findAllByStatusAndBusinessStatus(
                StoreStatus.ACTIVE,
                BusinessStatus.OPEN
        );
        Map<Long, StoreScheduleResponse> schedules =
                storeScheduleService.findAllForEvaluation(stores, now);
        for (Store store : stores) {
            if (!operatingHoursPolicy.isWithinOperatingHours(
                    store, now, schedules.get(store.getId())
            )) {
                store.changeBusinessStatus(BusinessStatus.PRE_OPEN);
            }
        }
    }
}
