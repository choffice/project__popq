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
                or (
                  store.storeType = com.example.project_popq.store.domain.StoreType.EVENT_COMMERCE
                  and lower(coalesce(store.eventName, '')) like lower(concat('%', :query, '%'))
                )
                or exists (
                  select product.id
                  from Product product
                  join product.availability availability
                  where product.store = store
                    and product.status = com.example.project_popq.product.domain.CatalogStatus.ACTIVE
                    and availability.customerAppEnabled = true
                    and (availability.salesStartAt is null or availability.salesStartAt <= :now)
                    and (availability.salesEndAt is null or availability.salesEndAt >= :now)
                    and lower(product.name) like lower(concat('%', :query, '%'))
                )
              )
              and (:tag is null or lower(tag.name) = lower(:tag))
              and (
                store.storeType = com.example.project_popq.store.domain.StoreType.LOCAL_STORE
                or store.operationEndDate >= :today
              )
            order by store.id desc
            """)
    List<Store> searchPublicStores(
            @Param("query") String query,
            @Param("tag") String tag,
            @Param("now") java.time.Instant now,
            @Param("today") LocalDate today
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

    @Query("""
            select store
            from Store store
            where store.id = :storeId
              and store.status = com.example.project_popq.store.domain.StoreStatus.ACTIVE
              and store.businessStatus in :businessStatuses
              and (
                store.storeType = com.example.project_popq.store.domain.StoreType.LOCAL_STORE
                or store.operationEndDate >= :today
              )
            """)
    Optional<Store> findPublicDetail(
            @Param("storeId") Long storeId,
            @Param("businessStatuses") Collection<BusinessStatus> businessStatuses,
            @Param("today") LocalDate today
    );

    Optional<Store> findByIdAndStatusAndBusinessStatusIn(
            Long id,
            StoreStatus status,
            Collection<BusinessStatus> businessStatuses
    );

    long countByStatus(StoreStatus status);
}
