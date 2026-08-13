package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.ProductOptionGroup;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductOptionGroupRepository
        extends JpaRepository<ProductOptionGroup, Long> {

    @EntityGraph(attributePaths = {"product", "options"})
    List<ProductOptionGroup> findAllByStoreOptionGroupTemplateIdOrderByProductIdAsc(
            Long templateId
    );

    long countByStoreOptionGroupTemplateId(Long templateId);

    Optional<ProductOptionGroup> findByIdAndProductIdAndStoreOptionGroupTemplateId(
            Long id,
            Long productId,
            Long templateId
    );
}
