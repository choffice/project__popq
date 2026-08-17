package com.example.project_popq.auth.dto;

import com.example.project_popq.auth.validation.AuthValidationPatterns;
import com.example.project_popq.user.domain.PlatformRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record SignupRequest(
        @NotBlank @Email @Size(max = 255)
        @Pattern(regexp = AuthValidationPatterns.EMAIL, message = "올바른 이메일 형식이 아닙니다.")
        String email,
        @NotBlank
        @Size(min = 8, max = 64)
        @Pattern(
                regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$",
                message = "비밀번호는 영문과 숫자를 포함해야 합니다."
        )
        String password,
        @NotBlank
        @Size(max = 7, message = "닉네임은 7자 이하로 입력해 주세요.")
        @Pattern(
                regexp = "^[A-Za-z0-9 \\x{3040}-\\x{30FF}\\x{3400}-\\x{4DBF}\\x{4E00}-\\x{9FFF}\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+$",
                message = "닉네임에는 한글, 영문, 숫자, 일본어, 한자와 공백만 사용할 수 있습니다."
        )
        String name,
        @NotBlank
        @Pattern(
                regexp = "^01[0-9]-?\\d{3,4}-?\\d{4}$",
                message = "전화번호 형식이 올바르지 않습니다."
        )
        String phone,
        @NotNull PlatformRole role,
        @Size(max = 100) String emailVerificationToken
) {
}
