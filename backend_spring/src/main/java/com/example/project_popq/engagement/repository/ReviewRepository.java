package com.example.project_popq.engagement.repository;

import com.example.project_popq.engagement.domain.Review;
import com.example.project_popq.engagement.domain.ReviewStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReviewRepository extends JpaRepository<Review, Long> {

    boolean existsByOrderId(Long orderId);

    @EntityGraph(attributePaths = {"order", "user", "store"})
    Optional<Review> findById(Long id);

    @EntityGraph(attributePaths = {"order", "user", "store"})
    List<Review> findAllByUserIdOrderByCreatedAtDesc(Long userId);

    @EntityGraph(attributePaths = {"user", "store"})
    List<Review> findAllByStoreIdAndStatusOrderByCreatedAtDesc(
            Long storeId,
            ReviewStatus status
    );

    long countByUserIdAndStatus(Long userId, ReviewStatus status);
}
