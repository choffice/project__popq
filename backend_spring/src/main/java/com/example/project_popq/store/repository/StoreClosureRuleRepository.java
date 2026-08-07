package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.StoreClosureRule;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreClosureRuleRepository
        extends JpaRepository<StoreClosureRule, Long> {
    List<StoreClosureRule> findAllByStoreIdOrderByIdAsc(Long storeId);
    List<StoreClosureRule> findAllByStoreIdIn(List<Long> storeIds);
    void deleteAllByStoreId(Long storeId);
}
