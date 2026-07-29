package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.StoreTable;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreTableRepository extends JpaRepository<StoreTable, Long> {

    Optional<StoreTable> findByIdAndStoreId(Long id, Long storeId);

    boolean existsByStoreIdAndTableCodeIgnoreCase(Long storeId, String tableCode);

    List<StoreTable> findAllByStoreIdOrderByIdAsc(Long storeId);
}

