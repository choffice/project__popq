package com.example.project_popq.order.repository;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.dto.VisitedStoreResponse;
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

    List<Order> findAllByStoreIdOrderByCreatedAtAsc(
        Long storeId
    );

    List<Order> findAllByStoreIdAndStatusOrderByCreatedAtDesc(
        Long storeId,
        OrderStatus status
    );

    List<Order> findAllByStoreIdAndStatusInOrderByCreatedAtDesc(
        Long storeId,
        List<OrderStatus> statuses
    );

    List<Order> findAllByStoreIdOrderByCreatedAtDesc(
        Long storeId
    );

    List<Order> findAllByStoreIdAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(
        Long storeId,
        List<OrderStatus> statuses,
        Instant fromInclusive,
        Instant toExclusive
    );

    @EntityGraph(attributePaths = {"store", "items"})
    List<Order> findAllByStoreIdInAndStatusOrderByCreatedAtDesc(
        List<Long> storeIds,
        OrderStatus status,
        org.springframework.data.domain.Pageable pageable
    );

    /*
     * AI 예상 준비시간 계산에 사용한다.
     *
     * 해당 매장의 특정 상태 주문 개수를 DB에서 직접 COUNT한다.
     *
     * 예:
     * PLACED 주문 수 = 아직 판매자가 처리하지 않은 대기 주문
     */
    long countByStoreIdAndStatus(
        Long storeId,
        OrderStatus status
    );

    /*
     * 여러 상태를 묶어서 개수를 계산한다.
     *
     * AI에서는 ACCEPTED / PREPARING 상태를
     * 현재 처리 중인 주문으로 계산할 때 사용한다.
     */
    long countByStoreIdAndStatusIn(
        Long storeId,
        List<OrderStatus> statuses
    );

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

    List<Order> findAllByUserIdOrderByCreatedAtDesc(
        Long userId
    );

    long countByUserId(
        Long userId
    );

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

    /**
     * 고객이 결제까지 완료한 주문이 있는 매장을 매장별로 묶어,
     * 가장 최근 결제 시각순으로 반환합니다. ("방문 기록")
     */
    @Query("""
            select new com.example.project_popq.order.dto.VisitedStoreResponse(
                o.store.id,
                o.store.name,
                o.store.representativeCategory,
                o.store.imageUrl,
                max(p.approvedAt)
            )
            from Order o
            join Payment p on p.order = o
            where o.user.id = :userId
              and p.status = :paymentStatus
            group by o.store.id, o.store.name, o.store.representativeCategory, o.store.imageUrl
            order by max(p.approvedAt) desc
            """)
    List<VisitedStoreResponse> findVisitedStoresByUserId(
        @Param("userId") Long userId,
        @Param("paymentStatus") PaymentStatus paymentStatus
    );
}