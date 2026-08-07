package com.example.project_popq.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateNameRequest(
        @NotBlank @Size(min = 2, max = 100) String name
) {
}
