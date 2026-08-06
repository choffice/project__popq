package com.example.project_popq.store.service;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.repository.StoreRepository;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class StoreBusinessStatusScheduler {

    private final StoreRepository storeRepository;
    private final StoreOperatingHoursPolicy operatingHoursPolicy;

    @Scheduled(fixedDelayString = "${popq.store.closure-check-ms:60000}")
    @Transactional
    public void closeStoresOutsideOperatingHours() {
        Instant now = Instant.now();
        for (Store store : storeRepository.findAllByStatusAndBusinessStatus(
                StoreStatus.ACTIVE,
                BusinessStatus.OPEN
        )) {
            if (store.getOpenTime() != null
                    && store.getCloseTime() != null
                    && !operatingHoursPolicy.isWithinOperatingHours(store, now)) {
                store.changeBusinessStatus(BusinessStatus.PRE_OPEN);
            }
        }
    }
}
