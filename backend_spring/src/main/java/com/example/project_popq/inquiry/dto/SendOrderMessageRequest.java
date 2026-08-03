package com.example.project_popq.inquiry.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendOrderMessageRequest(
    @NotBlank
    @Size(max = 2000)
    String content
) {

  public String normalizedContent() {
    return content == null ? "" : content.trim();
  }
}