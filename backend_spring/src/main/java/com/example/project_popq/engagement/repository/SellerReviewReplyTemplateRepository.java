package com.example.project_popq.engagement.repository;

import com.example.project_popq.engagement.domain.SellerReviewReplyTemplate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SellerReviewReplyTemplateRepository
        extends JpaRepository<SellerReviewReplyTemplate, Long> {

    List<SellerReviewReplyTemplate> findAllByStoreIdOrderByIdAsc(Long storeId);

    Optional<SellerReviewReplyTemplate> findByIdAndStoreId(Long id, Long storeId);

    long countByStoreId(Long storeId);
}
