package com.example.project_popq.auth.social;

import com.example.project_popq.auth.config.NaverOAuthProperties;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Component
public class NaverAccessTokenVerifier {

  private final RestClient restClient;

  public NaverAccessTokenVerifier(
      NaverOAuthProperties properties
  ) {
    this.restClient = RestClient.builder()
        .baseUrl(properties.apiBaseUrl())
        .build();
  }

  public NaverIdentity verify(String accessToken) {
    if (accessToken == null || accessToken.isBlank()) {
      throw new IllegalArgumentException(
          "네이버 Access Token이 비어 있습니다."
      );
    }

    try {
      NaverUserInfoResponse result = restClient.get()
          .uri("/v1/nid/me")
          .header(
              HttpHeaders.AUTHORIZATION,
              "Bearer " + accessToken
          )
          .retrieve()
          .body(NaverUserInfoResponse.class);

      validateResponse(result);

      NaverUserInfoResponse.NaverProfile profile =
          result.response();

      return new NaverIdentity(
          profile.id().trim(),
          resolveEmail(profile),
          resolveName(profile)
      );
    } catch (RestClientException exception) {
      throw new IllegalArgumentException(
          "네이버 토큰 검증에 실패했습니다.",
          exception
      );
    }
  }

  private void validateResponse(
      NaverUserInfoResponse result
  ) {
    if (result == null
        || !"00".equals(result.resultcode())
        || result.response() == null
        || result.response().id() == null
        || result.response().id().isBlank()) {
      throw new IllegalArgumentException(
          "유효하지 않은 네이버 토큰입니다."
      );
    }
  }

  private String resolveEmail(
      NaverUserInfoResponse.NaverProfile profile
  ) {
    if (profile.email() == null
        || profile.email().isBlank()) {
      return null;
    }

    return profile.email().trim().toLowerCase();
  }

  private String resolveName(
      NaverUserInfoResponse.NaverProfile profile
  ) {
    if (profile.name() != null
        && !profile.name().isBlank()) {
      return profile.name().trim();
    }

    if (profile.nickname() != null
        && !profile.nickname().isBlank()) {
      return profile.nickname().trim();
    }

    return "네이버 사용자";
  }
}