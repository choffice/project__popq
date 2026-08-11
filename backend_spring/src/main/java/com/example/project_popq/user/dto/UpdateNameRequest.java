package com.example.project_popq.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateNameRequest(
        @NotBlank
        @Size(max = 7, message = "닉네임은 7자 이하로 입력해 주세요.")
        @Pattern(
                regexp = "^[A-Za-z0-9 \\x{3040}-\\x{30FF}\\x{3400}-\\x{4DBF}\\x{4E00}-\\x{9FFF}\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+$",
                message = "닉네임에는 한글, 영문, 숫자, 일본어, 한자와 공백만 사용할 수 있습니다."
        )
        String name
) {
}
