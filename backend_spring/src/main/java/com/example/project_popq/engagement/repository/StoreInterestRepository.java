package com.example.project_popq.engagement.repository;

import com.example.project_popq.engagement.domain.StoreInterest;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoreInterestRepository
        extends JpaRepository<StoreInterest, Long> {

    Optional<StoreInterest> findByUserIdAndStoreId(Long userId, Long storeId);

    boolean existsByUserIdAndStoreId(Long userId, Long storeId);

    @EntityGraph(attributePaths = "store")
    List<StoreInterest> findAllByUserIdOrderByCreatedAtDesc(Long userId);

    @EntityGraph(attributePaths = "user")
    List<StoreInterest> findAllByStoreId(Long storeId);

    long countByUserId(Long userId);

    @Query("""
            select interest.store.id, count(interest)
            from StoreInterest interest
            where interest.store.id in :storeIds
            group by interest.store.id
            """)
    List<Object[]> countByStoreIds(
            @Param("storeIds") List<Long> storeIds
    );
}