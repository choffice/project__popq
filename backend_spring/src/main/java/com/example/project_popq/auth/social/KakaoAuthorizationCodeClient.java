package com.example.project_popq.auth.social;

import com.example.project_popq.auth.config.KakaoOAuthProperties;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Component
public class KakaoAuthorizationCodeClient {

  private final KakaoOAuthProperties properties;
  private final RestClient restClient;

  public KakaoAuthorizationCodeClient(
      KakaoOAuthProperties properties
  ) {
    this.properties = properties;
    this.restClient = RestClient.builder()
        .baseUrl(properties.authBaseUrl())
        .build();
  }

  public String exchange(
      String authorizationCode
  ) {
    validateConfiguration();

    if (!StringUtils.hasText(authorizationCode)) {
      throw new IllegalArgumentException(
          "카카오 인증 코드가 비어 있습니다."
      );
    }

    MultiValueMap<String, String> form =
        new LinkedMultiValueMap<>();

    form.add("grant_type", "authorization_code");
    form.add("client_id", properties.restApiKey());
    form.add("redirect_uri", properties.sellerRedirectUri());
    form.add("code", authorizationCode);

    if (StringUtils.hasText(properties.clientSecret())) {
      form.add("client_secret", properties.clientSecret());
    }

    try {
      KakaoTokenResponse response = restClient.post()
          .uri("/oauth/token")
          .contentType(MediaType.APPLICATION_FORM_URLENCODED)
          .body(form)
          .retrieve()
          .body(KakaoTokenResponse.class);

      if (response == null
          || !StringUtils.hasText(response.accessToken())
          || response.expiresIn() == null
          || response.expiresIn() <= 0) {
        throw new IllegalArgumentException(
            "카카오 Access Token 응답이 올바르지 않습니다."
        );
      }

      return response.accessToken();
    } catch (RestClientException exception) {
      throw new IllegalArgumentException(
          "카카오 인증 코드를 토큰으로 교환하지 못했습니다.",
          exception
      );
    }
  }

  private void validateConfiguration() {
    if (!StringUtils.hasText(properties.authBaseUrl())
        || !StringUtils.hasText(properties.restApiKey())
        || !StringUtils.hasText(properties.sellerRedirectUri())) {
      throw new IllegalStateException(
          "카카오 REST API 설정이 필요합니다."
      );
    }
  }
}
