package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.dto.KakaoAddressSearchResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Service
public class KakaoLocationService {

  private final RestClient restClient;
  private final String restApiKey;

  public KakaoLocationService(
      @Value("${popq.kakao.rest-api-base-url}")
      String restApiBaseUrl,
      @Value("${popq.kakao.rest-api-key}")
      String restApiKey
  ) {
    this.restClient = RestClient.builder()
        .baseUrl(restApiBaseUrl)
        .build();

    this.restApiKey =
        restApiKey == null
            ? ""
            : restApiKey.trim();
  }

  public List<KakaoAddressSearchResponse>
  searchAddress(
      String query
  ) {
    String normalizedQuery =
        query == null
            ? ""
            : query.trim();

    if (normalizedQuery.isEmpty()) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST,
          "검색할 주소를 입력해 주세요."
      );
    }

    if (restApiKey.isEmpty()) {
      throw new BusinessException(
          ErrorCode.KAKAO_API_NOT_CONFIGURED,
          "POPQ_KAKAO_REST_API_KEY가 설정되지 않았습니다."
      );
    }

    try {
      Map<?, ?> response =
          restClient.get()
              .uri(
                  uriBuilder ->
                      uriBuilder
                          .path(
                              "/v2/local/search/address.json"
                          )
                          .queryParam(
                              "query",
                              normalizedQuery
                          )
                          .build()
              )
              .header(
                  HttpHeaders.AUTHORIZATION,
                  "KakaoAK " + restApiKey
              )
              .retrieve()
              .body(Map.class);

      if (response == null) {
        return List.of();
      }

      Object documentsValue =
          response.get("documents");

      if (!(documentsValue
          instanceof List<?> documents)) {
        return List.of();
      }

      List<KakaoAddressSearchResponse> results =
          new ArrayList<>();

      for (Object documentValue : documents) {
        if (!(documentValue
            instanceof Map<?, ?> document)) {
          continue;
        }

        KakaoAddressSearchResponse result =
            parseDocument(document);

        if (result != null) {
          results.add(result);
        }
      }

      return results;
    } catch (BusinessException exception) {
      throw exception;
    } catch (
        RestClientException
        | NumberFormatException exception
    ) {
      throw new BusinessException(
          ErrorCode.KAKAO_LOCATION_UNAVAILABLE,
          "카카오 주소 검색 중 오류가 발생했습니다."
      );
    }
  }

  private KakaoAddressSearchResponse parseDocument(
      Map<?, ?> document
  ) {
    String longitudeText =
        readString(
            document,
            "x"
        );

    String latitudeText =
        readString(
            document,
            "y"
        );

    if (longitudeText.isEmpty()
        || latitudeText.isEmpty()) {
      return null;
    }

    double longitude =
        Double.parseDouble(longitudeText);

    double latitude =
        Double.parseDouble(latitudeText);

    Map<?, ?> roadAddress =
        readMap(
            document,
            "road_address"
        );

    Map<?, ?> jibunAddress =
        readMap(
            document,
            "address"
        );

    String roadAddressName =
        readString(
            roadAddress,
            "address_name"
        );

    String jibunAddressName =
        readString(
            jibunAddress,
            "address_name"
        );

    String fallbackAddressName =
        readString(
            document,
            "address_name"
        );

    String addressName =
        firstNotBlank(
            roadAddressName,
            jibunAddressName,
            fallbackAddressName
        );

    if (addressName.isEmpty()) {
      return null;
    }

    String zoneNo =
        readString(
            roadAddress,
            "zone_no"
        );

    return new KakaoAddressSearchResponse(
        addressName,
        emptyToNull(roadAddressName),
        emptyToNull(jibunAddressName),
        emptyToNull(zoneNo),
        latitude,
        longitude
    );
  }

  private Map<?, ?> readMap(
      Map<?, ?> source,
      String key
  ) {
    Object value = source.get(key);

    if (value instanceof Map<?, ?> map) {
      return map;
    }

    return Map.of();
  }

  private String readString(
      Map<?, ?> source,
      String key
  ) {
    Object value = source.get(key);

    if (value == null) {
      return "";
    }

    return value.toString().trim();
  }

  private String firstNotBlank(
      String... values
  ) {
    for (String value : values) {
      if (value != null
          && !value.isBlank()) {
        return value.trim();
      }
    }

    return "";
  }

  private String emptyToNull(
      String value
  ) {
    return value == null
        || value.isBlank()
        ? null
        : value.trim();
  }
}