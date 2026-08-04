package com.example.project_popq.store.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.store.dto.PublicStoreResponse;
import com.example.project_popq.store.service.PublicStoreQueryService;
import com.example.project_popq.product.dto.ProductDetailResponse;
import com.example.project_popq.product.dto.ProductSummaryResponse;
import com.example.project_popq.store.dto.StoreWalkingRouteResponse;
import com.example.project_popq.product.service.CatalogService;
import com.example.project_popq.store.service.StoreWalkingRouteService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import java.math.BigDecimal;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/v1/public/stores")
@RequiredArgsConstructor
public class PublicStoreController {

    private final PublicStoreQueryService publicStoreQueryService;
    private final CatalogService catalogService;
    private final StoreWalkingRouteService storeWalkingRouteService;


    @GetMapping
    public ApiResponse<List<PublicStoreResponse>> search(
            @RequestParam(required = false) String query,
            @RequestParam(required = false) String tag,
            @RequestParam(required = false)
            @DecimalMin("-90.0") @DecimalMax("90.0") BigDecimal latitude,
            @RequestParam(required = false)
            @DecimalMin("-180.0") @DecimalMax("180.0") BigDecimal longitude,
            @RequestParam(required = false) Double radiusKm
    ) {
        return ApiResponse.success(publicStoreQueryService.search(
                query,
                tag,
                latitude,
                longitude,
                radiusKm
        ));
    }

    @GetMapping("/{storeId}")
    public ApiResponse<PublicStoreResponse> findDetail(
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                publicStoreQueryService.findDetail(storeId)
        );
    }

    @GetMapping("/{storeId}/walking-route")
    public ApiResponse<StoreWalkingRouteResponse> findWalkingRoute(
        @PathVariable Long storeId,

        @RequestParam
        @DecimalMin("-90.0")
        @DecimalMax("90.0")
        BigDecimal startLatitude,

        @RequestParam
        @DecimalMin("-180.0")
        @DecimalMax("180.0")
        BigDecimal startLongitude
    ) {
        return ApiResponse.success(
            storeWalkingRouteService.findWalkingRoute(
                storeId,
                startLatitude,
                startLongitude
            )
        );
    }

    @GetMapping("/{storeId}/products")
    public ApiResponse<List<ProductSummaryResponse>> findProducts(
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                catalogService.findCustomerProducts(storeId)
        );
    }

    @GetMapping("/{storeId}/products/{productId}")
    public ApiResponse<ProductDetailResponse> findProduct(
            @PathVariable Long storeId,
            @PathVariable Long productId
    ) {
        return ApiResponse.success(
                catalogService.findCustomerProduct(storeId, productId)
        );
    }
}
