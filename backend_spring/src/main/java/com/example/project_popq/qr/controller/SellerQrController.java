package com.example.project_popq.qr.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.qr.dto.IssueQrCodeRequest;
import com.example.project_popq.qr.dto.QrDetailResponse;
import com.example.project_popq.qr.dto.QrIssuedResponse;
import com.example.project_popq.qr.dto.QrSummaryResponse;
import com.example.project_popq.qr.dto.ReissueQrCodeRequest;
import com.example.project_popq.qr.service.SellerQrService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores/{storeId}/qr-codes")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerQrController {

    private final CurrentUserService currentUserService;
    private final SellerQrService sellerQrService;

    @GetMapping
    public ApiResponse<List<QrSummaryResponse>> findAll(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @RequestParam(defaultValue = "false") boolean includeArchived
    ) {
        return ApiResponse.success(
                sellerQrService.findAll(
                        currentUserService.getRequired(jwt),
                        storeId,
                        includeArchived
                )
        );
    }

    @PostMapping("/{qrCodeId}/archive")
    public ApiResponse<QrSummaryResponse> archive(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId
    ) {
        return ApiResponse.success(
                sellerQrService.archive(
                        currentUserService.getRequired(jwt),
                        storeId,
                        qrCodeId
                )
        );
    }

    @PostMapping("/{qrCodeId}/restore")
    public ApiResponse<QrSummaryResponse> restore(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId
    ) {
        return ApiResponse.success(
                sellerQrService.restore(
                        currentUserService.getRequired(jwt),
                        storeId,
                        qrCodeId
                )
        );
    }

    @PostMapping
    public ResponseEntity<ApiResponse<QrIssuedResponse>> issue(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @RequestBody IssueQrCodeRequest request
    ) {
        QrIssuedResponse issued = sellerQrService.issue(
                currentUserService.getRequired(jwt),
                storeId,
                request
        );
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(issued));
    }

    @GetMapping("/{qrCodeId}")
    public ApiResponse<QrDetailResponse> findDetail(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId
    ) {
        return ApiResponse.success(
                sellerQrService.findDetail(
                        currentUserService.getRequired(jwt),
                        storeId,
                        qrCodeId
                )
        );
    }

    @PostMapping("/{qrCodeId}/revoke")
    public ApiResponse<QrSummaryResponse> revoke(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId
    ) {
        return ApiResponse.success(
                sellerQrService.revoke(
                        currentUserService.getRequired(jwt),
                        storeId,
                        qrCodeId
                )
        );
    }

    @PostMapping("/{qrCodeId}/deactivate")
    public ApiResponse<QrSummaryResponse> deactivate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId
    ) {
        return ApiResponse.success(
                sellerQrService.deactivate(
                        currentUserService.getRequired(jwt),
                        storeId,
                        qrCodeId
                )
        );
    }

    @PostMapping("/{qrCodeId}/activate")
    public ApiResponse<QrSummaryResponse> activate(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId
    ) {
        return ApiResponse.success(
                sellerQrService.activate(
                        currentUserService.getRequired(jwt),
                        storeId,
                        qrCodeId
                )
        );
    }

    @PostMapping("/{qrCodeId}/reissue")
    public ResponseEntity<ApiResponse<QrIssuedResponse>> reissue(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long qrCodeId,
            @RequestBody ReissueQrCodeRequest request
    ) {
        QrIssuedResponse reissued = sellerQrService.reissue(
                currentUserService.getRequired(jwt),
                storeId,
                qrCodeId,
                request
        );
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(reissued));
    }
}
