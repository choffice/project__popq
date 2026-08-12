package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportInquiryStatus;
import jakarta.validation.constraints.NotNull;

public record ChangeSupportInquiryStatusRequest(

    @NotNull
    SupportInquiryStatus status
) {
}