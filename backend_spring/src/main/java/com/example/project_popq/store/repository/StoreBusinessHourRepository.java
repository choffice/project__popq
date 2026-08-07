package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.StoreBusinessHour;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreBusinessHourRepository
        extends JpaRepository<StoreBusinessHour, Long> {
    List<StoreBusinessHour> findAllByStoreIdOrderByDayOfWeekAsc(Long storeId);
    List<StoreBusinessHour> findAllByStoreIdIn(List<Long> storeIds);
    void deleteAllByStoreId(Long storeId);
}
