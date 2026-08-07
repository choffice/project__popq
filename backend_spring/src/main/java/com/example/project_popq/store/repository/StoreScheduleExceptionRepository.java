package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.StoreScheduleException;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreScheduleExceptionRepository
        extends JpaRepository<StoreScheduleException, Long> {
    List<StoreScheduleException> findAllByStoreIdOrderByStartDateAscIdAsc(Long storeId);
    List<StoreScheduleException>
    findAllByStoreIdInAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
            List<Long> storeIds,
            LocalDate rangeEnd,
            LocalDate rangeStart
    );
    void deleteAllByStoreId(Long storeId);
}
