package com.example.project_popq.order.repository;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.payment.domain.PaymentStatus;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OrderRepository extends JpaRepository<Order, Long> {

    Optional<Order> findByIdempotencyKey(String idempotencyKey);

    Optional<Order> findByOrderPublicId(String orderPublicId);

    Optional<Order> findByOrderPublicIdAndUserId(
            String orderPublicId,
            Long userId
    );

    @EntityGraph(attributePaths = {"store", "items"})
    Optional<Order> findDetailedByOrderPublicId(String orderPublicId);

    @EntityGraph(attributePaths = {"store", "items"})
    Optional<Order> findDetailedByOrderPublicIdAndStoreId(
            String orderPublicId,
            Long storeId
    );

    List<Order> findAllByStoreIdAndStatusOrderByCreatedAtAsc(
            Long storeId,
            OrderStatus status
    );

    List<Order> findAllByStoreIdOrderByCreatedAtAsc(Long storeId);

    List<Order> findAllByStoreIdAndStatusOrderByCreatedAtDesc(
            Long storeId,
            OrderStatus status
    );

    List<Order> findAllByStoreIdAndStatusInOrderByCreatedAtDesc(
            Long storeId,
            List<OrderStatus> statuses
    );

    List<Order> findAllByStoreIdOrderByCreatedAtDesc(Long storeId);

    @Query("""
            select o.store.id, o.status, count(o)
            from Order o
            where o.store.id in :storeIds
              and o.status in :statuses
            group by o.store.id, o.status
            """)
    List<Object[]> countByStoreIdsAndStatuses(
            @Param("storeIds") List<Long> storeIds,
            @Param("statuses") List<OrderStatus> statuses
    );

    List<Order> findAllByUserIdOrderByCreatedAtDesc(Long userId);

    long countByUserId(Long userId);

    @EntityGraph(attributePaths = "statusHistories")
    @Query("""
            select o
            from Order o
            where o.store.id = :storeId
              and o.status = :status
              and exists (
                    select p.id
                    from Payment p
                    where p.order = o
                      and p.status = :paymentStatus
              )
              and exists (
                    select h.id
                    from OrderStatusHistory h
                    where h.order = o
                      and h.currentStatus = :status
                      and h.changedAt >= :fromInclusive
                      and h.changedAt < :toExclusive
              )
            order by o.createdAt asc
            """)
    List<Order> findCompletedForAnalytics(
            @Param("storeId") Long storeId,
            @Param("status") OrderStatus status,
            @Param("paymentStatus") PaymentStatus paymentStatus,
            @Param("fromInclusive") Instant fromInclusive,
            @Param("toExclusive") Instant toExclusive
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select o
            from Order o
            where o.orderPublicId = :orderPublicId
            """)
    Optional<Order> findForUpdateByOrderPublicId(
            @Param("orderPublicId") String orderPublicId
    );
}
