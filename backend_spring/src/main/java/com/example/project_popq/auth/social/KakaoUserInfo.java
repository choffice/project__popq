package com.example.project_popq.auth.social;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

public record KakaoUserInfo(
    Long id,

    @JsonProperty("kakao_account")
    KakaoAccount kakaoAccount,

    Map<String, Object> properties
) {

  public record KakaoAccount(
      String email,

      @JsonProperty("is_email_valid")
      Boolean emailValid,

      @JsonProperty("is_email_verified")
      Boolean emailVerified,

      Profile profile
  ) {
  }

  public record Profile(
      String nickname
  ) {
  }
}