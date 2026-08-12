package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportInquiryCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateSupportInquiryRequest(

    @NotNull
    SupportInquiryCategory category,

    @NotBlank
    @Size(max = 200)
    String title,

    @NotBlank
    @Size(max = 3000)
    String content
) {
}