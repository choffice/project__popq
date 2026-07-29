package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.ProductCategory;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductCategoryRepository
        extends JpaRepository<ProductCategory, Long> {

    boolean existsByStoreIdAndNameIgnoreCase(Long storeId, String name);

    Optional<ProductCategory> findByIdAndStoreId(Long id, Long storeId);

    List<ProductCategory> findAllByStoreIdOrderByDisplayOrderAscIdAsc(Long storeId);
}

