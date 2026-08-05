package com.example.project_popq.store.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.store.dto.ChangeBusinessStatusRequest;
import com.example.project_popq.store.dto.CreateStoreRequest;
import com.example.project_popq.store.dto.CreateStoreTableRequest;
import com.example.project_popq.store.dto.SellerStoreDetailResponse;
import com.example.project_popq.store.dto.StoreSummaryResponse;
import com.example.project_popq.store.dto.StoreTableResponse;
import com.example.project_popq.store.dto.UpdateStoreRequest;
import com.example.project_popq.store.service.StoreApplicationService;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerStoreController {

    private final CurrentUserService currentUserService;
    private final StoreApplicationService storeApplicationService;

    @GetMapping
    public ApiResponse<List<StoreSummaryResponse>> findMyStores(
        @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
            storeApplicationService.findMyStores(
                currentUserService.getRequired(jwt)
            )
        );
    }

    @GetMapping("/{storeId}")
    public ApiResponse<SellerStoreDetailResponse> findOne(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId
    ) {
        return ApiResponse.success(
            storeApplicationService.findOne(
                currentUserService.getRequired(jwt),
                storeId
            )
        );
    }

    @PostMapping
    public ResponseEntity<ApiResponse<StoreSummaryResponse>> create(
        @AuthenticationPrincipal Jwt jwt,
        @Valid @RequestBody CreateStoreRequest request
    ) {
        StoreSummaryResponse created =
            storeApplicationService.create(
                currentUserService.getRequired(jwt),
                request
            );

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.success(created));
    }

    @PatchMapping("/{storeId}")
    public ApiResponse<SellerStoreDetailResponse> update(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @Valid @RequestBody UpdateStoreRequest request
    ) {
        return ApiResponse.success(
            storeApplicationService.update(
                currentUserService.getRequired(jwt),
                storeId,
                request
            )
        );
    }

    @DeleteMapping("/{storeId}")
    public ApiResponse<Boolean> delete(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId
    ) {
        storeApplicationService.delete(
            currentUserService.getRequired(jwt),
            storeId
        );

        return ApiResponse.success(true);
    }

    @PatchMapping("/{storeId}/business-status")
    public ApiResponse<StoreSummaryResponse> changeBusinessStatus(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @Valid @RequestBody ChangeBusinessStatusRequest request
    ) {
        return ApiResponse.success(
            storeApplicationService.changeBusinessStatus(
                currentUserService.getRequired(jwt),
                storeId,
                request
            )
        );
    }

    @GetMapping("/{storeId}/tables")
    public ApiResponse<List<StoreTableResponse>> findTables(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId
    ) {
        return ApiResponse.success(
            storeApplicationService.findTables(
                currentUserService.getRequired(jwt),
                storeId
            )
        );
    }

    @PostMapping("/{storeId}/tables")
    public ResponseEntity<ApiResponse<StoreTableResponse>> createTable(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable Long storeId,
        @Valid @RequestBody CreateStoreTableRequest request
    ) {
        StoreTableResponse created =
            storeApplicationService.createTable(
                currentUserService.getRequired(jwt),
                storeId,
                request
            );

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.success(created));
    }
}
