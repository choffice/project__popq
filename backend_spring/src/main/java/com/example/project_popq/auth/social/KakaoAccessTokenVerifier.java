package com.example.project_popq.auth.social;

import com.example.project_popq.auth.config.KakaoOAuthProperties;
import com.example.project_popq.user.domain.PlatformRole;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Component
public class KakaoAccessTokenVerifier {

  private final KakaoOAuthProperties properties;
  private final RestClient restClient;

  public KakaoAccessTokenVerifier(
      KakaoOAuthProperties properties
  ) {
    this.properties = properties;
    this.restClient = RestClient.builder()
        .baseUrl(properties.apiBaseUrl())
        .build();
  }

  public KakaoIdentity verify(
      String accessToken,
      PlatformRole requestedRole
  ) {
    if (accessToken == null || accessToken.isBlank()) {
      throw new IllegalArgumentException(
          "카카오 Access Token이 비어 있습니다."
      );
    }

    try {
      KakaoTokenInfo tokenInfo = retrieveTokenInfo(
          accessToken
      );

      validateTokenInfo(tokenInfo, requestedRole);

      KakaoUserInfo userInfo = retrieveUserInfo(
          accessToken
      );

      if (userInfo == null
          || userInfo.id() == null
          || !userInfo.id().equals(tokenInfo.id())) {
        throw new IllegalArgumentException(
            "카카오 사용자 정보가 일치하지 않습니다."
        );
      }

      String providerUserId =
          tokenInfo.appId() + ":" + userInfo.id();

      return new KakaoIdentity(
          providerUserId,
          resolveEmail(userInfo),
          resolveName(userInfo)
      );
    } catch (RestClientException exception) {
      throw new IllegalArgumentException(
          "카카오 토큰 검증에 실패했습니다.",
          exception
      );
    }
  }

  private KakaoTokenInfo retrieveTokenInfo(
      String accessToken
  ) {
    return restClient.get()
        .uri("/v1/user/access_token_info")
        .header(
            HttpHeaders.AUTHORIZATION,
            "Bearer " + accessToken
        )
        .retrieve()
        .body(KakaoTokenInfo.class);
  }

  private KakaoUserInfo retrieveUserInfo(
      String accessToken
  ) {
    return restClient.get()
        .uri("/v2/user/me")
        .header(
            HttpHeaders.AUTHORIZATION,
            "Bearer " + accessToken
        )
        .retrieve()
        .body(KakaoUserInfo.class);
  }

  private void validateTokenInfo(
      KakaoTokenInfo tokenInfo,
      PlatformRole requestedRole
  ) {
    if (tokenInfo == null
        || tokenInfo.id() == null
        || tokenInfo.appId() == null
        || tokenInfo.expiresIn() == null
        || tokenInfo.expiresIn() <= 0) {
      throw new IllegalArgumentException(
          "유효하지 않은 카카오 토큰입니다."
      );
    }

    Long expectedAppId = switch (requestedRole) {
      case CUSTOMER -> properties.customerAppId();
      case SELLER -> properties.sellerAppId();
      default -> throw new IllegalArgumentException(
          "지원하지 않는 로그인 역할입니다."
      );
    };

    if (expectedAppId == null
        || !expectedAppId.equals(tokenInfo.appId())) {
      throw new IllegalArgumentException(
          "카카오 앱 정보가 일치하지 않습니다."
      );
    }
  }

  private String resolveEmail(KakaoUserInfo userInfo) {
    KakaoUserInfo.KakaoAccount account =
        userInfo.kakaoAccount();

    if (account == null
        || account.email() == null
        || account.email().isBlank()
        || !Boolean.TRUE.equals(account.emailValid())
        || !Boolean.TRUE.equals(account.emailVerified())) {
      return null;
    }

    return account.email().trim().toLowerCase();
  }

  private String resolveName(KakaoUserInfo userInfo) {
    KakaoUserInfo.KakaoAccount account =
        userInfo.kakaoAccount();

    if (account != null
        && account.profile() != null
        && account.profile().nickname() != null
        && !account.profile().nickname().isBlank()) {
      return account.profile().nickname().trim();
    }

    Map<String, Object> properties = userInfo.properties();

    if (properties != null) {
      Object nickname = properties.get("nickname");

      if (nickname instanceof String value
          && !value.isBlank()) {
        return value.trim();
      }
    }

    return "카카오 사용자";
  }
}