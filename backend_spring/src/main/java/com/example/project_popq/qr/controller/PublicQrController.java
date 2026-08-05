package com.example.project_popq.qr.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.product.dto.ProductDetailResponse;
import com.example.project_popq.product.dto.ProductSummaryResponse;
import com.example.project_popq.product.service.CatalogService;
import com.example.project_popq.qr.config.QrProperties;
import com.example.project_popq.qr.dto.QrContextResponse;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.OpenedGuestSession;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/qr")
@RequiredArgsConstructor
public class PublicQrController {

    public static final String GUEST_SESSION_COOKIE = "POPQ_GUEST_SESSION";

    private final GuestQrService guestQrService;
    private final CatalogService catalogService;
    private final QrProperties properties;

    @PostMapping("/{token}/sessions")
    public ResponseEntity<ApiResponse<QrContextResponse>> open(
            @PathVariable String token,
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String existingSessionToken
    ) {
        OpenedGuestSession opened = guestQrService.open(
                token,
                existingSessionToken
        );
        ResponseCookie cookie = ResponseCookie
                .from(GUEST_SESSION_COOKIE, opened.rawToken())
                .httpOnly(true)
                .secure(properties.cookieSecure())
                .sameSite("Lax")
                .path("/")
                .maxAge(guestQrService.cookieMaxAge(opened.expiresAt()))
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, cookie.toString())
                .body(ApiResponse.success(opened.context()));
    }

    @GetMapping("/context")
    public ApiResponse<QrContextResponse> context(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken
    ) {
        return ApiResponse.success(guestQrService.resolve(sessionToken).context());
    }

    @GetMapping("/products")
    public ApiResponse<List<ProductSummaryResponse>> products(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken
    ) {
        ResolvedGuestSession session = guestQrService.resolve(sessionToken);
        return ApiResponse.success(
                catalogService.findQrProducts(session.storeId())
        );
    }

    @GetMapping("/products/{productId}")
    public ApiResponse<ProductDetailResponse> product(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken,
            @PathVariable Long productId
    ) {
        ResolvedGuestSession session = guestQrService.resolve(sessionToken);
        return ApiResponse.success(
                catalogService.findQrProduct(session.storeId(), productId)
        );
    }
}
