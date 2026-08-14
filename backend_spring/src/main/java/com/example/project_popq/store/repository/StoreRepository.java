package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.StoreStatus;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.time.LocalDate;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoreRepository extends JpaRepository<Store, Long>,
        JpaSpecificationExecutor<Store> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select store from Store store where store.id = :storeId")
    Optional<Store> findForUpdateById(@Param("storeId") Long storeId);

    @Query("""
            select distinct store
            from Store store
            left join StoreTag storeTag on storeTag.store = store
            left join storeTag.tag tag
            where store.status = com.example.project_popq.store.domain.StoreStatus.ACTIVE
              and store.businessStatus in (
                com.example.project_popq.store.domain.BusinessStatus.PRE_OPEN,
                com.example.project_popq.store.domain.BusinessStatus.OPEN
              )
              and (
                :query is null
                or lower(store.name) like lower(concat('%', :query, '%'))
                or lower(coalesce(store.representativeCategory, '')) like lower(concat('%', :query, '%'))
                or lower(coalesce(store.address, '')) like lower(concat('%', :query, '%'))
                or lower(coalesce(tag.name, '')) like lower(concat('%', :query, '%'))
              )
              and (:tag is null or lower(tag.name) = lower(:tag))
            order by store.id desc
            """)
    List<Store> searchPublicStores(
            @Param("query") String query,
            @Param("tag") String tag
    );

    @Query("""
            select store
            from Store store
            where store.storeType = com.example.project_popq.store.domain.StoreType.EVENT_COMMERCE
              and store.eventName is not null
              and trim(store.eventName) <> ''
              and store.operationEndDate >= :today
              and store.status = com.example.project_popq.store.domain.StoreStatus.ACTIVE
              and store.businessStatus in (
                com.example.project_popq.store.domain.BusinessStatus.PRE_OPEN,
                com.example.project_popq.store.domain.BusinessStatus.OPEN
              )
              and store.latitude is not null
              and store.longitude is not null
            """)
    List<Store> findEventNameSuggestionCandidates(
            @Param("today") LocalDate today
    );

    Optional<Store> findByIdAndStatusAndBusinessStatusIn(
            Long id,
            com.example.project_popq.store.domain.StoreStatus status,
            Collection<com.example.project_popq.store.domain.BusinessStatus> businessStatuses
    );

    long countByStatus(StoreStatus status);
}
