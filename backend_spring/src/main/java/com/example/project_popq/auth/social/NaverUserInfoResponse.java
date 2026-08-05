package com.example.project_popq.auth.social;

public record NaverUserInfoResponse(
    String resultcode,
    String message,
    NaverProfile response
) {

  public record NaverProfile(
      String id,
      String email,
      String name,
      String nickname
  ) {
  }
}