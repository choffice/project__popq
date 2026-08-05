package com.example.project_popq.inquiry.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendOrderMessageRequest(
    @NotBlank
    @Size(max = 2000)
    String content,

    @Size(max = 64)
    String clientMessageId
) {

  public String normalizedContent() {
    return content == null ? "" : content.trim();
  }

  public String normalizedClientMessageId() {
    if (clientMessageId == null) {
      return null;
    }

    String normalized = clientMessageId.trim();

    if (normalized.isEmpty()) {
      return null;
    }

    return normalized;
  }
}