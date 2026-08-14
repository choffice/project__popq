package com.example.project_popq.location.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.location.dto.RegionCenterResponse;
import com.example.project_popq.store.dto.KakaoPlaceSearchResponse;
import com.example.project_popq.store.service.KakaoLocationService;
import java.util.Comparator;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RegionCenterService {

  private static final String ALL_DISTRICT_LABEL = "전체";

  private static final List<String> REGION_1_DEPTH_SUFFIXES = List.of(
      "특별자치시",
      "특별자치도",
      "특별시",
      "광역시",
      "자치도"
  );

  private final KakaoLocationService kakaoLocationService;

  /**
   * 홈/탐색에서 사용할 지역의 대표 좌표를 조회합니다.
   *
   * <p>소비자 주소나 배송지를 저장하는 기능이 아니라,
   * 사용자가 선택한 시/도 + 구/군의 행정기관 위치를
   * 주변 업체 탐색의 기준 좌표로 사용하기 위한 기능입니다.</p>
   */
  public RegionCenterResponse findCenter(
      String province,
      String district
  ) {
    String normalizedProvince = normalizeRequired(
        province,
        "시/도를 선택해 주세요."
    );

    String normalizedDistrict = normalizeDistrict(district);

    String searchKeyword = buildSearchKeyword(
        normalizedProvince,
        normalizedDistrict
    );

    List<KakaoPlaceSearchResponse> results =
        kakaoLocationService.searchPlaces(searchKeyword);

    if (results == null || results.isEmpty()) {
      throw new BusinessException(
          ErrorCode.RESOURCE_NOT_FOUND,
          "선택한 지역의 대표 위치를 찾지 못했습니다."
      );
    }

    KakaoPlaceSearchResponse bestMatch = results.stream()
        .max(
            Comparator.comparingInt(
                result -> score(
                    result,
                    normalizedProvince,
                    normalizedDistrict
                )
            )
        )
        .orElseThrow(() -> new BusinessException(
            ErrorCode.RESOURCE_NOT_FOUND,
            "선택한 지역의 대표 위치를 찾지 못했습니다."
        ));

    return new RegionCenterResponse(
        buildDisplayLabel(
            normalizedProvince,
            normalizedDistrict
        ),
        bestMatch.latitude(),
        bestMatch.longitude()
    );
  }

  private String buildSearchKeyword(
      String province,
      String district
  ) {
    if (district == null) {
      return province + "청";
    }

    return province + " " + district + "청";
  }

  private int score(
      KakaoPlaceSearchResponse result,
      String province,
      String district
  ) {
    String placeName = safe(result.placeName());
    String addressName = safe(result.addressName());
    String roadAddressName = safe(result.roadAddressName());

    String expectedOfficeName =
        district == null
            ? province + "청"
            : district + "청";

    int score = 0;

    if (placeName.equals(expectedOfficeName)) {
      score += 100;
    } else if (placeName.contains(expectedOfficeName)) {
      score += 70;
    }

    if (containsRegion(addressName, province, district)) {
      score += 50;
    }

    if (containsRegion(roadAddressName, province, district)) {
      score += 50;
    }

    if (addressName.startsWith(province)
        || roadAddressName.startsWith(province)) {
      score += 20;
    }

    return score;
  }

  private boolean containsRegion(
      String address,
      String province,
      String district
  ) {
    if (address.isBlank() || !address.contains(province)) {
      return false;
    }

    return district == null || address.contains(district);
  }

  private String buildDisplayLabel(
      String province,
      String district
  ) {
    String shortProvince = shortenRegion1(province);

    if (district == null) {
      return shortProvince;
    }

    return shortProvince + " " + district;
  }

  private String shortenRegion1(String region1) {
    for (String suffix : REGION_1_DEPTH_SUFFIXES) {
      if (region1.endsWith(suffix)) {
        return region1.substring(
            0,
            region1.length() - suffix.length()
        );
      }
    }

    if (region1.endsWith("도")) {
      return region1.substring(
          0,
          region1.length() - 1
      );
    }

    return region1;
  }

  private String normalizeRequired(
      String value,
      String message
  ) {
    String normalized = safe(value);

    if (normalized.isEmpty()) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST,
          message
      );
    }

    return normalized;
  }

  private String normalizeDistrict(String district) {
    String normalized = safe(district);

    if (normalized.isEmpty()
        || ALL_DISTRICT_LABEL.equals(normalized)) {
      return null;
    }

    return normalized;
  }

  private String safe(String value) {
    return value == null ? "" : value.trim();
  }
}