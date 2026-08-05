package com.example.project_popq.auth.social;

import com.fasterxml.jackson.annotation.JsonProperty;

public record KakaoTokenInfo(
    Long id,

    @JsonProperty("expires_in")
    Long expiresIn,

    @JsonProperty("app_id")
    Long appId
) {
}