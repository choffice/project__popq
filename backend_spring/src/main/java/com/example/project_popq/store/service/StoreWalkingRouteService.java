package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.dto.PublicStoreResponse;
import com.example.project_popq.store.dto.StoreWalkingRouteResponse;
import java.math.BigDecimal;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Slf4j
@Service
public class StoreWalkingRouteService {

  private final PublicStoreQueryService publicStoreQueryService;
  private final RestClient kakaoRestClient;
  private final String kakaoRestApiKey;

  public StoreWalkingRouteService(
      PublicStoreQueryService publicStoreQueryService,
      @Value(
          "${popq.kakao.rest-api-base-url:"
              + "https://dapi.kakao.com}"
      )
      String kakaoRestApiBaseUrl,
      @Value("${popq.kakao.rest-api-key:}")
      String kakaoRestApiKey
  ) {
    this.publicStoreQueryService =
        publicStoreQueryService;

    this.kakaoRestApiKey =
        kakaoRestApiKey;

    this.kakaoRestClient =
        RestClient.builder()
            .baseUrl(kakaoRestApiBaseUrl)
            .build();
  }

  public StoreWalkingRouteResponse findWalkingRoute(
      Long storeId,
      BigDecimal startLatitude,
      BigDecimal startLongitude
  ) {
    validateApiKey();

    /*
     * 업체 ID를 좌표로 직접 받지 않고 DB에서 조회합니다.
     *
     * 클라이언트가 임의의 목적지를 계속 조회하는 것을 막고,
     * 실제 등록 업체만 도보 경로 대상으로 사용합니다.
     */
    PublicStoreResponse store =
        publicStoreQueryService.findDetail(storeId);

    if (store.latitude() == null ||
        store.longitude() == null) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST,
          "업체 위치 좌표가 등록되지 않았습니다."
      );
    }

    try {
      KakaoWalkingRouteResponse response =
          kakaoRestClient
              .get()
              .uri(uriBuilder ->
                  uriBuilder
                      .path(
                          "/v2/routing/walk"
                      )
                      /*
                       * 카카오 API 좌표 순서:
                       * x = 경도
                       * y = 위도
                       */
                      .queryParam(
                          "start_x",
                          startLongitude
                              .toPlainString()
                      )
                      .queryParam(
                          "start_y",
                          startLatitude
                              .toPlainString()
                      )
                      .queryParam(
                          "end_x",
                          store.longitude()
                              .toPlainString()
                      )
                      .queryParam(
                          "end_y",
                          store.latitude()
                              .toPlainString()
                      )
                      .queryParam(
                          "s_name",
                          "현재 위치"
                      )
                      .queryParam(
                          "e_name",
                          store.name()
                      )
                      .queryParam(
                          "input_coord",
                          "WGS84"
                      )
                      .build()
              )
              .header(
                  HttpHeaders.AUTHORIZATION,
                  "KakaoAK "
                      + kakaoRestApiKey
              )
              .retrieve()
              .body(
                  KakaoWalkingRouteResponse.class
              );

      KakaoWalkingRouteProperties properties =
          extractProperties(response);

      return new StoreWalkingRouteResponse(
          properties.totalDistance(),
          properties.totalTime(),
          properties.landingUrl()
      );
    } catch (RestClientException exception) {
      log.warn(
          "Failed to load walking route. "
              + "storeId={}",
          storeId,
          exception
      );

      throw new BusinessException(
          ErrorCode.WALKING_ROUTE_UNAVAILABLE
      );
    }
  }

  private void validateApiKey() {
    if (kakaoRestApiKey == null ||
        kakaoRestApiKey.isBlank()) {
      throw new BusinessException(
          ErrorCode.WALKING_ROUTE_UNAVAILABLE,
          "카카오 REST API 키가 설정되지 않았습니다."
      );
    }
  }

  private KakaoWalkingRouteProperties extractProperties(
      KakaoWalkingRouteResponse response
  ) {
    if (response == null ||
        response.route() == null ||
        response.route().properties() == null) {
      throw new BusinessException(
          ErrorCode.WALKING_ROUTE_UNAVAILABLE
      );
    }

    KakaoWalkingRouteProperties properties =
        response.route().properties();

    if (properties.totalDistance() == null ||
        properties.totalTime() == null) {
      throw new BusinessException(
          ErrorCode.WALKING_ROUTE_UNAVAILABLE
      );
    }

    return properties;
  }

  /*
   * 카카오 도보 경로 API 응답 중
   * 현재 화면에 필요한 요약 필드만 매핑합니다.
   */
  private record KakaoWalkingRouteResponse(
      KakaoWalkingRoute route
  ) {
  }

  private record KakaoWalkingRoute(
      KakaoWalkingRouteProperties properties
  ) {
  }

  private record KakaoWalkingRouteProperties(
      Long totalDistance,
      Long totalTime,
      String landingUrl
  ) {
  }
}