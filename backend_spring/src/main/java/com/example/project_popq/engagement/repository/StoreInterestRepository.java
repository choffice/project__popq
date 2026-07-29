package com.example.project_popq.engagement.repository;

import com.example.project_popq.engagement.domain.StoreInterest;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreInterestRepository
        extends JpaRepository<StoreInterest, Long> {

    Optional<StoreInterest> findByUserIdAndStoreId(Long userId, Long storeId);

    boolean existsByUserIdAndStoreId(Long userId, Long storeId);

    @EntityGraph(attributePaths = "store")
    List<StoreInterest> findAllByUserIdOrderByCreatedAtDesc(Long userId);

    long countByUserId(Long userId);
}
