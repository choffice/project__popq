package com.example.project_popq.product.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductCategory;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.dto.CategoryResponse;
import com.example.project_popq.product.dto.CreateCategoryRequest;
import com.example.project_popq.product.dto.CreateProductRequest;
import com.example.project_popq.product.dto.ProductDetailResponse;
import com.example.project_popq.product.dto.ProductSummaryResponse;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest.OptionGroupRequest;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest.OptionRequest;
import com.example.project_popq.product.dto.UpdateAvailabilityRequest;
import com.example.project_popq.product.dto.UpdateCategoryRequest;
import com.example.project_popq.product.dto.UpdateProductRequest;
import com.example.project_popq.product.repository.ProductCategoryRepository;
import com.example.project_popq.product.repository.ProductRepository;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CatalogService {

    private final StoreRepository storeRepository;
    private final ProductCategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional
    public CategoryResponse createCategory(
        User user,
        Long storeId,
        CreateCategoryRequest request
    ) {
        requireCatalogManager(user, storeId);

        String name = request.name().trim();

        if (categoryRepository
            .existsByStoreIdAndNameIgnoreCaseAndStatus(
                storeId,
                name,
                CatalogStatus.ACTIVE
            )) {
            throw new BusinessException(
                ErrorCode.DUPLICATE_CATEGORY
            );
        }

        Store store = getStore(storeId);

        ProductCategory category =
            categoryRepository.save(
                ProductCategory.create(
                    store,
                    name,
                    request.displayOrder()
                )
            );

        return CategoryResponse.from(category);
    }

    @Transactional(readOnly = true)
    public List<CategoryResponse> findCategories(
        User user,
        Long storeId
    ) {
        requireStoreMember(user, storeId);

        return categoryRepository
            .findAllByStoreIdAndStatusOrderByDisplayOrderAscIdAsc(
                storeId,
                CatalogStatus.ACTIVE
            )
            .stream()
            .map(CategoryResponse::from)
            .toList();
    }

    @Transactional
    public CategoryResponse updateCategory(
        User user,
        Long storeId,
        Long categoryId,
        UpdateCategoryRequest request
    ) {
        requireCatalogManager(user, storeId);

        ProductCategory category =
            getActiveCategory(
                storeId,
                categoryId
            );

        String name = request.name().trim();

        if (categoryRepository
            .existsByStoreIdAndNameIgnoreCaseAndIdNotAndStatus(
                storeId,
                name,
                categoryId,
                CatalogStatus.ACTIVE
            )) {
            throw new BusinessException(
                ErrorCode.DUPLICATE_CATEGORY
            );
        }

        category.update(
            name,
            request.displayOrder()
        );

        return CategoryResponse.from(category);
    }

    @Transactional
    public void deleteCategory(
        User user,
        Long storeId,
        Long categoryId
    ) {
        requireCatalogManager(user, storeId);

        ProductCategory category =
            getActiveCategory(
                storeId,
                categoryId
            );

        boolean hasActiveProducts =
            productRepository
                .existsByStoreIdAndCategoryIdAndStatus(
                    storeId,
                    categoryId,
                    CatalogStatus.ACTIVE
                );

        if (hasActiveProducts) {
            /*
             * 활성 메뉴가 남아 있는 카테고리는 삭제하지 않습니다.
             *
             * 연결된 메뉴를 먼저 삭제한 후 카테고리를
             * 삭제해야 기존 메뉴 참조 관계가 안전하게 유지됩니다.
             */
            throw new BusinessException(
                ErrorCode.INVALID_REQUEST
            );
        }

        /*
         * product_categories 테이블에는 사업장과 이름의
         * UNIQUE 제약조건이 있습니다.
         *
         * 삭제 상태만 변경하면 같은 이름으로 새 카테고리를
         * 다시 만들 수 없으므로, 삭제 전 내부 보관용 이름으로
         * 변경합니다.
         */
        category.update(
            "__deleted__" + category.getId(),
            category.getDisplayOrder()
        );

        category.delete();
    }

    @Transactional
    public ProductDetailResponse createProduct(
        User user,
        Long storeId,
        CreateProductRequest request
    ) {
        requireCatalogManager(user, storeId);

        Store store = getStore(storeId);

        ProductCategory category =
            getActiveCategory(
                storeId,
                request.categoryId()
            );

        Product product =
            productRepository.save(
                Product.create(
                    store,
                    category,
                    request.name().trim(),
                    normalize(
                        request.description()
                    ),
                    normalize(
                        request.imageUrl()
                    ),
                    request.basePrice()
                )
            );

        return ProductDetailResponse.from(
            product,
            Instant.now()
        );
    }

    @Transactional(readOnly = true)
    public List<ProductSummaryResponse> findSellerProducts(
        User user,
        Long storeId
    ) {
        requireStoreMember(user, storeId);

        Instant now = Instant.now();

        return productRepository
            .findAllByStoreIdAndStatusOrderByIdAsc(
                storeId,
                CatalogStatus.ACTIVE
            )
            .stream()
            .map(
                product ->
                    ProductSummaryResponse.from(
                        product,
                        now
                    )
            )
            .toList();
    }

    @Transactional(readOnly = true)
    public ProductDetailResponse findSellerProduct(
        User user,
        Long storeId,
        Long productId
    ) {
        requireStoreMember(user, storeId);

        return ProductDetailResponse.from(
            getActiveDetailedProduct(
                storeId,
                productId
            ),
            Instant.now()
        );
    }

    @Transactional
    public ProductDetailResponse updateProduct(
        User user,
        Long storeId,
        Long productId,
        UpdateProductRequest request
    ) {
        requireCatalogManager(user, storeId);

        Product product =
            getActiveDetailedProduct(
                storeId,
                productId
            );

        ProductCategory category =
            getActiveCategory(
                storeId,
                request.categoryId()
            );

        product.update(
            category,
            request.name().trim(),
            normalize(
                request.description()
            ),
            normalize(
                request.imageUrl()
            ),
            request.basePrice()
        );

        return ProductDetailResponse.from(
            product,
            Instant.now()
        );
    }

    @Transactional
    public void deleteProduct(
        User user,
        Long storeId,
        Long productId
    ) {
        requireCatalogManager(user, storeId);

        Product product =
            getActiveDetailedProduct(
                storeId,
                productId
            );

        /*
         * 상품 행과 옵션은 실제로 삭제하지 않습니다.
         *
         * 주문·결제 기록에서 기존 상품을 계속 참조할 수 있도록
         * 상태와 판매 가능 여부만 변경합니다.
         */
        product.delete();
    }

    @Transactional
    public ProductDetailResponse replaceOptions(
        User user,
        Long storeId,
        Long productId,
        ReplaceProductOptionsRequest request
    ) {
        requireCatalogManager(user, storeId);

        Product product =
            getActiveDetailedProduct(
                storeId,
                productId
            );

        validateOptionGroups(
            request.groups()
        );

        List<ProductOptionGroup> groups =
            request.groups()
                .stream()
                .map(
                    groupRequest ->
                        toOptionGroup(
                            product,
                            groupRequest
                        )
                )
                .toList();

        product.replaceOptionGroups(groups);
        productRepository.flush();

        return ProductDetailResponse.from(
            product,
            Instant.now()
        );
    }

    @Transactional
    public ProductDetailResponse updateAvailability(
        User user,
        Long storeId,
        Long productId,
        UpdateAvailabilityRequest request
    ) {
        requireStoreOperator(user, storeId);
        validateAvailability(request);

        Product product =
            getActiveDetailedProduct(
                storeId,
                productId
            );

        product.getAvailability().update(
            request.soldOut(),
            request.salesStartAt(),
            request.salesEndAt(),
            request.qrWebEnabled(),
            request.customerAppEnabled()
        );

        return ProductDetailResponse.from(
            product,
            Instant.now()
        );
    }

    @Transactional(readOnly = true)
    public List<ProductSummaryResponse> findQrProducts(
        Long storeId
    ) {
        Instant now = Instant.now();

        return productRepository
            .findAllByStoreIdAndStatusOrderByIdAsc(
                storeId,
                CatalogStatus.ACTIVE
            )
            .stream()
            .filter(
                product ->
                    product.getAvailability()
                        .isVisibleForQr(now)
            )
            .map(
                product ->
                    ProductSummaryResponse.from(
                        product,
                        now
                    )
            )
            .toList();
    }

    @Transactional(readOnly = true)
    public ProductDetailResponse findQrProduct(
        Long storeId,
        Long productId
    ) {
        Product product =
            getActiveDetailedProduct(
                storeId,
                productId
            );

        Instant now = Instant.now();

        if (!product.getAvailability()
            .isVisibleForQr(now)) {
            throw new BusinessException(
                ErrorCode.PRODUCT_NOT_FOUND
            );
        }

        return ProductDetailResponse.from(
            product,
            now
        );
    }

    @Transactional(readOnly = true)
    public List<ProductSummaryResponse> findCustomerProducts(
        Long storeId
    ) {
        requirePublicVisibleStore(storeId);

        Instant now = Instant.now();

        return productRepository
            .findAllByStoreIdAndStatusOrderByIdAsc(
                storeId,
                CatalogStatus.ACTIVE
            )
            .stream()
            .filter(
                product ->
                    product.getAvailability()
                        .isVisibleForCustomerApp(
                            now
                        )
            )
            .map(
                product ->
                    ProductSummaryResponse.from(
                        product,
                        now
                    )
            )
            .toList();
    }

    @Transactional(readOnly = true)
    public ProductDetailResponse findCustomerProduct(
        Long storeId,
        Long productId
    ) {
        requirePublicVisibleStore(storeId);

        Product product =
            getActiveDetailedProduct(
                storeId,
                productId
            );

        Instant now = Instant.now();

        if (!product.getAvailability()
            .isVisibleForCustomerApp(now)) {
            throw new BusinessException(
                ErrorCode.PRODUCT_NOT_FOUND
            );
        }

        return ProductDetailResponse.from(
            product,
            now
        );
    }

    private ProductOptionGroup toOptionGroup(
        Product product,
        OptionGroupRequest request
    ) {
        ProductOptionGroup group =
            ProductOptionGroup.create(
                product,
                request.name().trim(),
                request.minSelect(),
                request.maxSelect(),
                request.required(),
                request.displayOrder()
            );

        for (OptionRequest option
            : request.options()) {
            group.addOption(
                option.name().trim(),
                option.additionalPrice(),
                option.displayOrder()
            );
        }

        return group;
    }

    private void validateOptionGroups(
        List<OptionGroupRequest> groups
    ) {
        Set<String> groupNames =
            new HashSet<>();

        for (OptionGroupRequest group
            : groups) {
            if (group.maxSelect()
                < group.minSelect()
                || group.maxSelect()
                > group.options().size()
                || (group.required()
                && group.minSelect() == 0)) {
                throw new BusinessException(
                    ErrorCode.INVALID_PRODUCT_OPTION
                );
            }

            if (!groupNames.add(
                normalizeKey(
                    group.name()
                )
            )) {
                throw new BusinessException(
                    ErrorCode.INVALID_PRODUCT_OPTION
                );
            }

            Set<String> optionNames =
                new HashSet<>();

            for (OptionRequest option
                : group.options()) {
                if (!optionNames.add(
                    normalizeKey(
                        option.name()
                    )
                )) {
                    throw new BusinessException(
                        ErrorCode.INVALID_PRODUCT_OPTION
                    );
                }
            }
        }
    }

    private void validateAvailability(
        UpdateAvailabilityRequest request
    ) {
        if (request.salesStartAt() != null
            && request.salesEndAt() != null
            && !request.salesStartAt()
            .isBefore(
                request.salesEndAt()
            )) {
            throw new BusinessException(
                ErrorCode.INVALID_REQUEST
            );
        }
    }

    private Product getActiveDetailedProduct(
        Long storeId,
        Long productId
    ) {
        return productRepository
            .findDetailedByIdAndStoreIdAndStatus(
                productId,
                storeId,
                CatalogStatus.ACTIVE
            )
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.PRODUCT_NOT_FOUND
                )
            );
    }

    private ProductCategory getActiveCategory(
        Long storeId,
        Long categoryId
    ) {
        return categoryRepository
            .findByIdAndStoreIdAndStatus(
                categoryId,
                storeId,
                CatalogStatus.ACTIVE
            )
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.CATEGORY_NOT_FOUND
                )
            );
    }

    private Store getStore(Long storeId) {
        return storeRepository
            .findById(storeId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.STORE_NOT_FOUND
                )
            );
    }

    private void requirePublicVisibleStore(
        Long storeId
    ) {
        Store store = getStore(storeId);

        if (!store.isActive()
            || (store.getBusinessStatus() != BusinessStatus.OPEN
            && store.getBusinessStatus() != BusinessStatus.PRE_OPEN)) {
            throw new BusinessException(
                ErrorCode.STORE_NOT_FOUND
            );
        }
    }

    private void requireCatalogManager(
        User user,
        Long storeId
    ) {
        storeAuthorizationService.requireAnyRole(
            user.getId(),
            storeId,
            StoreRole.OWNER,
            StoreRole.MANAGER
        );
    }

    private void requireStoreOperator(
        User user,
        Long storeId
    ) {
        storeAuthorizationService.requireAnyRole(
            user.getId(),
            storeId,
            StoreRole.OWNER,
            StoreRole.MANAGER,
            StoreRole.STAFF
        );
    }

    private void requireStoreMember(
        User user,
        Long storeId
    ) {
        requireStoreOperator(
            user,
            storeId
        );
    }

    private String normalize(String value) {
        if (value == null
            || value.isBlank()) {
            return null;
        }

        return value.trim();
    }

    private String normalizeKey(
        String value
    ) {
        return value
            .trim()
            .toLowerCase(
                Locale.ROOT
            );
    }
}
