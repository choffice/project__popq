package com.example.project_popq.location.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.location.dto.ReverseGeocodeResponse;
import com.example.project_popq.location.service.ReverseGeocodeService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import java.math.BigDecimal;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/v1/public/location")
@RequiredArgsConstructor
public class PublicLocationController {

    private final ReverseGeocodeService reverseGeocodeService;

    @GetMapping("/reverse-geocode")
    public ApiResponse<ReverseGeocodeResponse> reverseGeocode(
            @RequestParam
            @DecimalMin("-90.0")
            @DecimalMax("90.0")
            BigDecimal latitude,

            @RequestParam
            @DecimalMin("-180.0")
            @DecimalMax("180.0")
            BigDecimal longitude
    ) {
        return ApiResponse.success(
                reverseGeocodeService.reverseGeocode(
                        latitude,
                        longitude
                )
        );
    }
}
