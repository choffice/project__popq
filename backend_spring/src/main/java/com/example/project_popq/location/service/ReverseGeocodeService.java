package com.example.project_popq.location.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.location.dto.ReverseGeocodeResponse;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.math.BigDecimal;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Slf4j
@Service
public class ReverseGeocodeService {

  private static final List<String> REGION_1_DEPTH_SUFFIXES = List.of(
      "특별자치시",
      "특별자치도",
      "특별시",
      "광역시",
      "자치도"
  );

  private final RestClient kakaoRestClient;
  private final String kakaoRestApiKey;

  public ReverseGeocodeService(
      @Value(
          "${popq.kakao.rest-api-base-url:"
              + "https://dapi.kakao.com}"
      )
      String kakaoRestApiBaseUrl,
      @Value("${popq.kakao.rest-api-key:}")
      String kakaoRestApiKey
  ) {
    this.kakaoRestApiKey = kakaoRestApiKey;

    this.kakaoRestClient =
        RestClient.builder()
            .baseUrl(kakaoRestApiBaseUrl)
            .build();
  }

  public ReverseGeocodeResponse reverseGeocode(
      BigDecimal latitude,
      BigDecimal longitude
  ) {
    validateApiKey();

    try {
      KakaoCoord2AddressResponse response =
          kakaoRestClient
              .get()
              .uri(uriBuilder ->
                  uriBuilder
                      .path(
                          "/v2/local/geo/coord2address.json"
                      )
                      /*
                       * 카카오 API 좌표 순서:
                       * x = 경도
                       * y = 위도
                       */
                      .queryParam(
                          "x",
                          longitude.toPlainString()
                      )
                      .queryParam(
                          "y",
                          latitude.toPlainString()
                      )
                      .build()
              )
              .header(
                  HttpHeaders.AUTHORIZATION,
                  "KakaoAK " + kakaoRestApiKey
              )
              .retrieve()
              .body(KakaoCoord2AddressResponse.class);

      String label = extractLabel(response);

      return new ReverseGeocodeResponse(label);
    } catch (RestClientException exception) {
      log.warn(
          "Failed to reverse geocode. "
              + "latitude={}, longitude={}",
          latitude,
          longitude,
          exception
      );

      throw new BusinessException(
          ErrorCode.REVERSE_GEOCODE_UNAVAILABLE
      );
    }
  }

  private void validateApiKey() {
    if (kakaoRestApiKey == null ||
        kakaoRestApiKey.isBlank()) {
      throw new BusinessException(
          ErrorCode.REVERSE_GEOCODE_UNAVAILABLE,
          "카카오 REST API 키가 설정되지 않았습니다."
      );
    }
  }

  private String extractLabel(
      KakaoCoord2AddressResponse response
  ) {
    if (response == null ||
        response.documents() == null ||
        response.documents().isEmpty()) {
      throw new BusinessException(
          ErrorCode.REVERSE_GEOCODE_UNAVAILABLE
      );
    }

    KakaoAddress address =
        response.documents().get(0).address();

    if (address == null ||
        address.region1DepthName() == null) {
      throw new BusinessException(
          ErrorCode.REVERSE_GEOCODE_UNAVAILABLE
      );
    }

    String region1 =
        shortenRegion1(address.region1DepthName());

    String region2 = address.region2DepthName();

    if (region2 == null || region2.isBlank()) {
      return region1;
    }

    return region1 + " " + region2;
  }

  /*
   * "부산광역시" -> "부산"처럼 시/도 접미사를 뗀 축약형을 만듭니다.
   */
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

  /*
   * 카카오 coord2address 응답 중 현재 화면에 필요한
   * 지번 주소 영역만 매핑합니다.
   */
  private record KakaoCoord2AddressResponse(
      List<KakaoDocument> documents
  ) {
  }

  private record KakaoDocument(
      KakaoAddress address
  ) {
  }

  private record KakaoAddress(
      @JsonProperty("region_1depth_name")
      String region1DepthName,
      @JsonProperty("region_2depth_name")
      String region2DepthName
  ) {
  }
}
