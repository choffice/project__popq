package com.example.project_popq.announcement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SaveAnnouncementRequest(
    @NotBlank @Size(max = 200) String title,
    @NotBlank @Size(max = 2000) String content,
    @Size(max = 1000) String imageUrl,
    boolean notifyInterestedCustomers
) {
}