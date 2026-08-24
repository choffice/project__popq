package com.example.project_popq.auth.social;

import com.example.project_popq.auth.config.NaverOAuthProperties;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Component
public class NaverAuthorizationCodeClient {

  private final NaverOAuthProperties properties;
  private final RestClient restClient;

  public NaverAuthorizationCodeClient(
      NaverOAuthProperties properties
  ) {
    this.properties = properties;
    this.restClient = RestClient.builder()
        .baseUrl(properties.authBaseUrl())
        .build();
  }

  public String exchange(String authorizationCode, String state) {
    validateConfiguration();

    if (!StringUtils.hasText(authorizationCode)
        || !StringUtils.hasText(state)) {
      throw new IllegalArgumentException(
          "네이버 인증 코드와 state가 필요합니다."
      );
    }

    MultiValueMap<String, String> form =
        new LinkedMultiValueMap<>();
    form.add("grant_type", "authorization_code");
    form.add("client_id", properties.clientId());
    form.add("client_secret", properties.clientSecret());
    form.add("redirect_uri", properties.sellerRedirectUri());
    form.add("code", authorizationCode);
    form.add("state", state);

    try {
      NaverTokenResponse response = restClient.post()
          .uri("/oauth2.0/token")
          .contentType(MediaType.APPLICATION_FORM_URLENCODED)
          .body(form)
          .retrieve()
          .body(NaverTokenResponse.class);

      if (response == null
          || StringUtils.hasText(response.error())
          || !StringUtils.hasText(response.accessToken())) {
        throw new IllegalArgumentException(
            "네이버 Access Token 응답이 올바르지 않습니다."
        );
      }

      return response.accessToken();
    } catch (RestClientException exception) {
      throw new IllegalArgumentException(
          "네이버 인증 코드를 토큰으로 교환하지 못했습니다.",
          exception
      );
    }
  }

  private void validateConfiguration() {
    if (!StringUtils.hasText(properties.authBaseUrl())
        || !StringUtils.hasText(properties.clientId())
        || !StringUtils.hasText(properties.clientSecret())
        || !StringUtils.hasText(properties.sellerRedirectUri())) {
      throw new IllegalStateException(
          "네이버 OAuth 설정이 필요합니다."
      );
    }
  }
}
