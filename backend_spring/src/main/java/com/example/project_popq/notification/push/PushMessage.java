package com.example.project_popq.notification.push;

import java.util.Map;

public record PushMessage(
    String token,
    String title,
    String body,
    Map<String, String> data,
    boolean alertEnabled
) {

  public PushMessage(
      String token,
      String title,
      String body,
      Map<String, String> data
  ) {
    this(
        token,
        title,
        body,
        data,
        true
    );
  }
}