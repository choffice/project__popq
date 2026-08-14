package com.example.project_popq.location.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.location.dto.ReverseGeocodeResponse;
import com.example.project_popq.location.service.ReverseGeocodeService;
import com.example.project_popq.store.dto.KakaoAddressSearchResponse;
import com.example.project_popq.store.service.KakaoLocationService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;
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
  private final KakaoLocationService kakaoLocationService;

  /**
   * 구매자 앱에서 업체를 탐색할 기준 위치를 찾기 위한 주소 검색입니다.
   *
   * 이 API는 사용자의 배송지/거주지 주소를 등록하는 기능이 아니라,
   * 검색 지도와 홈의 탐색 중심 좌표를 정하기 위한 공개 조회 API입니다.
   */
  @GetMapping("/addresses")
  public ApiResponse<List<KakaoAddressSearchResponse>> searchAddresses(
      @RequestParam
      @NotBlank(message = "검색할 지역이나 주소를 입력해 주세요.")
      @Size(
          max = 200,
          message = "검색어는 200자 이하로 입력해 주세요."
      )
      String query
  ) {
    return ApiResponse.success(
        kakaoLocationService.searchAddress(query)
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