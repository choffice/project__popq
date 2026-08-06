package com.example.project_popq.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdatePhoneRequest(
        @NotBlank
        @Pattern(
                regexp = "^01[0-9]-?\\d{3,4}-?\\d{4}$",
                message = "전화번호 형식이 올바르지 않습니다."
        )
        String phone
) {
}
