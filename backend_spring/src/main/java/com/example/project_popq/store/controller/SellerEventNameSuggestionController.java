package com.example.project_popq.store.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.store.dto.NearbyEventNameSuggestionResponse;
import com.example.project_popq.store.service.SellerEventNameSuggestionService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import java.math.BigDecimal;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/v1/seller/event-name-suggestions")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerEventNameSuggestionController {

    private final SellerEventNameSuggestionService suggestionService;

    @GetMapping
    public ApiResponse<List<NearbyEventNameSuggestionResponse>> findNearby(
            @RequestParam
            @DecimalMin("-90.0") @DecimalMax("90.0") BigDecimal latitude,
            @RequestParam
            @DecimalMin("-180.0") @DecimalMax("180.0") BigDecimal longitude,
            @RequestParam Double radiusKm
    ) {
        return ApiResponse.success(suggestionService.findNearby(
                latitude, longitude, radiusKm
        ));
    }
}
