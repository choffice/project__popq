package com.example.project_popq.point.repository;

import com.example.project_popq.point.domain.CustomerPointTransaction;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CustomerPointTransactionRepository
        extends JpaRepository<CustomerPointTransaction, Long> {

    boolean existsBySourceKey(String sourceKey);

    Optional<CustomerPointTransaction> findBySourceKey(String sourceKey);

    List<CustomerPointTransaction> findAllByUserIdOrderByOccurredAtDescIdDesc(
            Long userId
    );

    @Query("""
            select coalesce(sum(pointEntry.pointAmount), 0)
            from CustomerPointTransaction pointEntry
            where pointEntry.user.id = :userId
            """)
    long findBalanceByUserId(@Param("userId") Long userId);

    @Query("""
            select coalesce(sum(pointEntry.pointAmount), 0)
            from CustomerPointTransaction pointEntry
            where pointEntry.user.id = :userId
              and pointEntry.orderPublicId = :orderPublicId
            """)
    long findBalanceByUserIdAndOrderPublicId(
            @Param("userId") Long userId,
            @Param("orderPublicId") String orderPublicId
    );
}
