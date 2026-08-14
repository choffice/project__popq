package com.example.project_popq.location.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.location.dto.RegionCenterResponse;
import com.example.project_popq.location.dto.ReverseGeocodeResponse;
import com.example.project_popq.location.service.RegionCenterService;
import com.example.project_popq.location.service.ReverseGeocodeService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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
  private final RegionCenterService regionCenterService;

  /**
   * 홈/탐색에서 사용자가 선택한 시/도 + 구/군의 대표 탐색 좌표를 반환합니다.
   *
   * <p>소비자 주소/배송지를 등록하는 기능이 아니라,
   * 주변 업체를 조회하고 탐색 지도의 중심을 이동하기 위한 공개 조회 API입니다.</p>
   */
  @GetMapping("/region-center")
  public ApiResponse<RegionCenterResponse> regionCenter(
      @RequestParam
      @NotBlank(message = "시/도를 선택해 주세요.")
      @Size(max = 30, message = "시/도 값이 너무 깁니다.")
      String province,

      @RequestParam(defaultValue = "전체")
      @Size(max = 30, message = "구/군 값이 너무 깁니다.")
      String district
  ) {
    return ApiResponse.success(
        regionCenterService.findCenter(
            province,
            district
        )
    );
  }

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