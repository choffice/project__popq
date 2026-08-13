package com.example.project_popq.support.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendSupportMessageRequest (
  @NotBlank
  @Size(max = 3000)
  String content
){

}
