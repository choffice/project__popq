package com.example.project_popq.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdatePhoneRequest(
        @NotBlank
        @Pattern(
                regexp = "^010-?\\d{4}-?\\d{4}$",
                message = "전화번호를 다시 확인해 주세요."
        )
        String phone
) {
}
