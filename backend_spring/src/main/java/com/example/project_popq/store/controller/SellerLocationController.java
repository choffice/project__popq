package com.example.project_popq.store.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.store.dto.KakaoAddressSearchResponse;
import com.example.project_popq.store.dto.KakaoPlaceSearchResponse;
import com.example.project_popq.store.dto.KakaoReverseGeocodeResponse;
import com.example.project_popq.store.service.KakaoLocationService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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
@RequestMapping("/api/v1/seller/location")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerLocationController {

  private final KakaoLocationService
      kakaoLocationService;

  @GetMapping("/addresses")
  public ApiResponse<
      List<KakaoAddressSearchResponse>
      > searchAddress(
      @RequestParam
      @NotBlank(
          message =
              "검색할 주소를 입력해 주세요."
      )
      @Size(
          max = 200,
          message =
              "주소는 200자 이하로 입력해 주세요."
      )
      String query
  ) {
    return ApiResponse.success(
        kakaoLocationService.searchAddress(
            query
        )
    );
  }

  @GetMapping("/places")
  public ApiResponse<
      List<KakaoPlaceSearchResponse>
      > searchPlaces(
      @RequestParam
      @NotBlank(
          message =
              "검색할 업체명이나 키워드를 입력해 주세요."
      )
      @Size(
          max = 200,
          message =
              "검색어는 200자 이하로 입력해 주세요."
      )
      String query
  ) {
    return ApiResponse.success(
        kakaoLocationService.searchPlaces(
            query
        )
    );
  }

  @GetMapping("/reverse")
  public ApiResponse<KakaoReverseGeocodeResponse>
  reverseGeocode(
      @RequestParam
      double latitude,

      @RequestParam
      double longitude
  ) {
    return ApiResponse.success(
        kakaoLocationService.reverseGeocode(
            latitude,
            longitude
        )
    );
  }
}