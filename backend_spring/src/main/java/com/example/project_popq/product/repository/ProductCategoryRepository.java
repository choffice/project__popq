package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.ProductCategory;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductCategoryRepository
    extends JpaRepository<ProductCategory, Long> {

    boolean existsByStoreIdAndNameIgnoreCase(
        Long storeId,
        String name
    );

    boolean existsByStoreIdAndNameIgnoreCaseAndIdNot(
        Long storeId,
        String name,
        Long id
    );

    Optional<ProductCategory> findByIdAndStoreId(
        Long id,
        Long storeId
    );

    List<ProductCategory>
    findAllByStoreIdOrderByDisplayOrderAscIdAsc(
        Long storeId
    );

    /*
     * 아래부터 소프트 삭제 적용을 위한 ACTIVE 전용 조회입니다.
     */

    boolean existsByStoreIdAndNameIgnoreCaseAndStatus(
        Long storeId,
        String name,
        CatalogStatus status
    );

    boolean existsByStoreIdAndNameIgnoreCaseAndIdNotAndStatus(
        Long storeId,
        String name,
        Long id,
        CatalogStatus status
    );

    Optional<ProductCategory> findByIdAndStoreIdAndStatus(
        Long id,
        Long storeId,
        CatalogStatus status
    );

    List<ProductCategory>
    findAllByStoreIdAndStatusOrderByDisplayOrderAscIdAsc(
        Long storeId,
        CatalogStatus status
    );
}