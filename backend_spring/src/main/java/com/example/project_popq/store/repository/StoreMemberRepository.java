package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreMemberStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoreMemberRepository
    extends JpaRepository<StoreMember, Long> {

    boolean existsByStoreIdAndUserId(
        Long storeId,
        Long userId
    );

    Optional<StoreMember> findByStoreIdAndUserIdAndStatus(
        Long storeId,
        Long userId,
        StoreMemberStatus status
    );

    @EntityGraph(attributePaths = "store")
    List<StoreMember> findAllByUserIdAndStatusOrderByIdAsc(
        Long userId,
        StoreMemberStatus status
    );

    @EntityGraph(attributePaths = "store")
    List<StoreMember> findAllByUserIdAndStatusOrderByDisplayOrderAscIdAsc(
        Long userId,
        StoreMemberStatus status
    );

    @EntityGraph(attributePaths = "user")
    List<StoreMember> findAllByStoreIdAndStatusOrderByIdAsc(
        Long storeId,
        StoreMemberStatus status
    );

    @Query("""
        select coalesce(max(sm.displayOrder), -1)
        from StoreMember sm
        where sm.user.id = :userId
        """)
    int findMaxDisplayOrderByUserId(
        @Param("userId") Long userId
    );
}