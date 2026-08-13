package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.domain.CatalogStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductOptionGroupRepository
        extends JpaRepository<ProductOptionGroup, Long> {

    @EntityGraph(attributePaths = {"product", "options"})
    List<ProductOptionGroup> findAllByStoreOptionGroupTemplateIdAndProductStatusOrderByProductIdAsc(
            Long templateId,
            CatalogStatus productStatus
    );

    long countByStoreOptionGroupTemplateIdAndProductStatus(
            Long templateId,
            CatalogStatus productStatus
    );

    Optional<ProductOptionGroup> findByIdAndProductIdAndStoreOptionGroupTemplateIdAndProductStatus(
            Long id,
            Long productId,
            Long templateId,
            CatalogStatus productStatus
    );
}
