package com.example.project_popq.payment.repository;

import com.example.project_popq.payment.domain.Payment;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    Optional<Payment> findByOrderId(Long orderId);

    Optional<Payment> findByIdempotencyKey(String idempotencyKey);

    @EntityGraph(attributePaths = "order")
    Optional<Payment> findDetailedByOrderOrderPublicId(String orderPublicId);

    @EntityGraph(attributePaths = {"order", "refunds"})
    Optional<Payment> findByOrderOrderPublicIdAndOrderStoreId(
            String orderPublicId,
            Long storeId
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @EntityGraph(attributePaths = {"order", "refunds"})
    @Query("""
            select p
            from Payment p
            where p.order.id = :orderId
            """)
    Optional<Payment> findForUpdateByOrderId(@Param("orderId") Long orderId);
}
