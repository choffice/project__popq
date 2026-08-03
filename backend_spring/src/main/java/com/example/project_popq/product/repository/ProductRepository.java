package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.Product;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository
    extends JpaRepository<Product, Long> {

    /**
     * 선택한 사업장의 특정 상태 상품 목록을 조회합니다.
     *
     * 판매자·고객·QR 상품 목록에서는
     * CatalogStatus.ACTIVE를 전달해 삭제된 상품을 제외합니다.
     */
    @EntityGraph(
        attributePaths = {
            "category",
            "availability"
        }
    )
    List<Product> findAllByStoreIdAndStatusOrderByIdAsc(
        Long storeId,
        CatalogStatus status
    );

    /**
     * 기존 서비스 코드와의 단계별 호환을 위해 유지합니다.
     *
     * 다음 CatalogService 수정 단계에서
     * 상태 조건이 포함된 조회 메서드로 변경합니다.
     */
    @EntityGraph(
        attributePaths = {
            "category",
            "availability",
            "optionGroups"
        }
    )
    Optional<Product> findDetailedByIdAndStoreId(
        Long id,
        Long storeId
    );

    /**
     * 삭제되지 않은 상품만 상세 조회할 때 사용합니다.
     */
    @EntityGraph(
        attributePaths = {
            "category",
            "availability",
            "optionGroups"
        }
    )
    Optional<Product> findDetailedByIdAndStoreIdAndStatus(
        Long id,
        Long storeId,
        CatalogStatus status
    );

    /**
     * 카테고리에 활성 상태 메뉴가 남아 있는지 확인합니다.
     *
     * 활성 메뉴가 존재하는 카테고리는 바로 삭제하지 않고,
     * 메뉴를 먼저 삭제하도록 처리할 예정입니다.
     */
    boolean existsByStoreIdAndCategoryIdAndStatus(
        Long storeId,
        Long categoryId,
        CatalogStatus status
    );
}