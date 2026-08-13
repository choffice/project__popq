package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.StoreOptionGroupTemplate;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoreOptionGroupTemplateRepository
        extends JpaRepository<StoreOptionGroupTemplate, Long> {

    @EntityGraph(attributePaths = "options")
    List<StoreOptionGroupTemplate> findAllByStoreIdOrderByNameAsc(Long storeId);

    @EntityGraph(attributePaths = "options")
    Optional<StoreOptionGroupTemplate> findByIdAndStoreId(Long id, Long storeId);

    Optional<StoreOptionGroupTemplate> findByStoreIdAndNameIgnoreCase(
            Long storeId,
            String name
    );

    boolean existsByStoreIdAndNameIgnoreCaseAndIdNot(
            Long storeId,
            String name,
            Long id
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @EntityGraph(attributePaths = "options")
    @Query("""
            select template
            from StoreOptionGroupTemplate template
            where template.id = :templateId
              and template.store.id = :storeId
            """)
    Optional<StoreOptionGroupTemplate> findLockedByIdAndStoreId(
            @Param("templateId") Long templateId,
            @Param("storeId") Long storeId
    );
}
