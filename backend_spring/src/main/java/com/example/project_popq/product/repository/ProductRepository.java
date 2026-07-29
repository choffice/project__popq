package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.Product;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, Long> {

    @EntityGraph(attributePaths = {"category", "availability"})
    List<Product> findAllByStoreIdAndStatusOrderByIdAsc(
            Long storeId,
            CatalogStatus status
    );

    @EntityGraph(attributePaths = {
            "category",
            "availability",
            "optionGroups"
    })
    Optional<Product> findDetailedByIdAndStoreId(Long id, Long storeId);
}
