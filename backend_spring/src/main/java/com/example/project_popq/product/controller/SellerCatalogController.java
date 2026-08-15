package com.example.project_popq.product.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.product.dto.CategoryResponse;
import com.example.project_popq.product.dto.BulkApplyStoreOptionTemplateRequest;
import com.example.project_popq.product.dto.CreateCategoryRequest;
import com.example.project_popq.product.dto.CreateProductRequest;
import com.example.project_popq.product.dto.ProductDetailResponse;
import com.example.project_popq.product.dto.ProductSummaryResponse;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest;
import com.example.project_popq.product.dto.StoreOptionTemplateRequest;
import com.example.project_popq.product.dto.StoreOptionTemplateResponse;
import com.example.project_popq.product.dto.StoreOptionTemplateUsageResponse;
import com.example.project_popq.product.dto.UpdateAvailabilityRequest;
import com.example.project_popq.product.dto.UpdateCategoryRequest;
import com.example.project_popq.product.dto.UpdateProductRequest;
import com.example.project_popq.product.service.CatalogService;
import com.example.project_popq.product.service.StoreOptionTemplateService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores/{storeId}")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerCatalogController {

    private final CurrentUserService currentUserService;
    private final CatalogService catalogService;
    private final StoreOptionTemplateService optionTemplateService;

    @GetMapping("/option-group-templates")
    public ApiResponse<List<StoreOptionTemplateResponse>> findOptionTemplates(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(optionTemplateService.findAll(
                currentUserService.getRequired(jwt), storeId
        ));
    }

    @GetMapping("/option-group-templates/{templateId}")
    public ApiResponse<StoreOptionTemplateResponse> findOptionTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long templateId
    ) {
        return ApiResponse.success(optionTemplateService.findOne(
                currentUserService.getRequired(jwt), storeId, templateId
        ));
    }

    @PostMapping("/option-group-templates")
    public ResponseEntity<ApiResponse<StoreOptionTemplateResponse>>
    createOptionTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @Valid @RequestBody StoreOptionTemplateRequest request
    ) {
        StoreOptionTemplateResponse created = optionTemplateService.create(
                currentUserService.getRequired(jwt), storeId, request
        );
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(created));
    }

    @GetMapping("/option-group-templates/{templateId}/products")
    public ApiResponse<StoreOptionTemplateUsageResponse> findOptionTemplateUsage(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long templateId
    ) {
        return ApiResponse.success(optionTemplateService.findUsage(
                currentUserService.getRequired(jwt), storeId, templateId
        ));
    }

    @PostMapping("/option-group-templates/{templateId}/apply")
    public ApiResponse<StoreOptionTemplateResponse> applyOptionTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long templateId,
            @Valid @RequestBody BulkApplyStoreOptionTemplateRequest request
    ) {
        return ApiResponse.success(optionTemplateService.applyToAll(
                currentUserService.getRequired(jwt), storeId, templateId, request
        ));
    }

    @DeleteMapping("/option-group-templates/{templateId}")
    public ApiResponse<Boolean> deleteOptionTemplate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long templateId
    ) {
        optionTemplateService.deleteIfUnused(
                currentUserService.getRequired(jwt), storeId, templateId
        );
        return ApiResponse.success(true);
    }

    @GetMapping("/categories")
    public ApiResponse<List<CategoryResponse>> findCategories(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId
    ) {
        return ApiResponse.success(
            catalogService.findCategories(
                currentUserService.getRequired(jwt),
                storeId
            )
        );
    }

    @PostMapping("/categories")
    public ResponseEntity<ApiResponse<CategoryResponse>> createCategory(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @Valid @RequestBody CreateCategoryRequest request
    ) {
        CategoryResponse created = catalogService.createCategory(
            currentUserService.getRequired(jwt),
            storeId,
            request
        );

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.success(created));
    }

    @PatchMapping("/categories/{categoryId}")
    public ApiResponse<CategoryResponse> updateCategory(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long categoryId,
        @Valid @RequestBody UpdateCategoryRequest request
    ) {
        return ApiResponse.success(
            catalogService.updateCategory(
                currentUserService.getRequired(jwt),
                storeId,
                categoryId,
                request
            )
        );
    }

    @DeleteMapping("/categories/{categoryId}")
    public ApiResponse<Boolean> deleteCategory(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long categoryId
    ) {
        catalogService.deleteCategory(
            currentUserService.getRequired(jwt),
            storeId,
            categoryId
        );

        return ApiResponse.success(true);
    }

    @GetMapping("/products")
    public ApiResponse<List<ProductSummaryResponse>> findProducts(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId
    ) {
        return ApiResponse.success(
            catalogService.findSellerProducts(
                currentUserService.getRequired(jwt),
                storeId
            )
        );
    }

    @PostMapping("/products")
    public ResponseEntity<ApiResponse<ProductDetailResponse>> createProduct(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @Valid @RequestBody CreateProductRequest request
    ) {
        ProductDetailResponse created =
            catalogService.createProduct(
                currentUserService.getRequired(jwt),
                storeId,
                request
            );

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.success(created));
    }

    @GetMapping("/products/{productId}")
    public ApiResponse<ProductDetailResponse> findProduct(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long productId
    ) {
        return ApiResponse.success(
            catalogService.findSellerProduct(
                currentUserService.getRequired(jwt),
                storeId,
                productId
            )
        );
    }

    @PatchMapping("/products/{productId}")
    public ApiResponse<ProductDetailResponse> updateProduct(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long productId,
        @Valid @RequestBody UpdateProductRequest request
    ) {
        return ApiResponse.success(
            catalogService.updateProduct(
                currentUserService.getRequired(jwt),
                storeId,
                productId,
                request
            )
        );
    }

    @DeleteMapping("/products/{productId}")
    public ApiResponse<Boolean> deleteProduct(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long productId
    ) {
        catalogService.deleteProduct(
            currentUserService.getRequired(jwt),
            storeId,
            productId
        );

        return ApiResponse.success(true);
    }

    @PutMapping("/products/{productId}/options")
    public ApiResponse<ProductDetailResponse> replaceOptions(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long productId,
        @Valid @RequestBody ReplaceProductOptionsRequest request
    ) {
        return ApiResponse.success(
            catalogService.replaceOptions(
                currentUserService.getRequired(jwt),
                storeId,
                productId,
                request
            )
        );
    }

    @PatchMapping("/products/{productId}/availability")
    public ApiResponse<ProductDetailResponse> updateAvailability(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @PathVariable Long productId,
        @RequestBody UpdateAvailabilityRequest request
    ) {
        return ApiResponse.success(
            catalogService.updateAvailability(
                currentUserService.getRequired(jwt),
                storeId,
                productId,
                request
            )
        );
    }
}
