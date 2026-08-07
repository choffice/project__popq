package com.example.project_popq.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthSignupLoginIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SellerProfileRepository sellerProfileRepository;

    @Test
    void sellerCanSignUpAndLoginWithEmailAndPassword() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "signup-seller@popq.test",
                                  "password": "password1",
                                  "name": "가입 판매자",
                                  "phone": "010-1234-5678",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.data.user.email").value("signup-seller@popq.test"))
                .andExpect(jsonPath("$.data.user.role").value("SELLER"));

        Long userId = userRepository.findByEmailIgnoreCase("signup-seller@popq.test")
                .orElseThrow()
                .getId();
        assertThat(sellerProfileRepository.findByUserId(userId)).isPresent();

        String loginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "signup-seller@popq.test",
                                  "password": "password1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String accessToken = com.jayway.jsonpath.JsonPath.read(loginResponse, "$.data.accessToken");

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value("signup-seller@popq.test"));
    }

    @Test
    void publicSignupRejectsAdminRole() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "public-admin@popq.test",
                                  "password": "password1",
                                  "name": "공개 관리자",
                                  "phone": "010-1234-9876",
                                  "role": "ADMIN"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("INVALID_SIGNUP_ROLE"));

        assertThat(userRepository.findByEmailIgnoreCase("public-admin@popq.test"))
                .isEmpty();
    }

    @Test
    void signUpRejectsDuplicateEmail() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "duplicate-seller@popq.test",
                                  "password": "password1",
                                  "name": "중복 판매자",
                                  "phone": "010-1111-1111",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "DUPLICATE-SELLER@popq.test",
                                  "password": "password2",
                                  "name": "중복 판매자2",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("DUPLICATE_USER"));
    }

    @Test
    void signUpRejectsWeakPassword() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "weak-password@popq.test",
                                  "password": "abcdefgh",
                                  "name": "약한 비밀번호",
                                  "phone": "010-2222-2222",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"));
    }

    @Test
    void loginRejectsWrongPassword() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "wrong-password@popq.test",
                                  "password": "password1",
                                  "name": "비밀번호 테스트",
                                  "phone": "010-3333-3333",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "wrong-password@popq.test",
                                  "password": "wrongpassword1"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void loginRejectsUnknownEmail() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "unknown-user@popq.test",
                                  "password": "password1"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void devLoginUserCannotLoginWithPasswordUntilPasswordIsSet() throws Exception {
        mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "dev-only@popq.test",
                                  "name": "개발 로그인 전용",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "dev-only@popq.test",
                                  "password": "password1"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void signUpRejectsDuplicatePhone() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "phone-owner@popq.test",
                                  "password": "password1",
                                  "name": "번호소유자",
                                  "phone": "010-7000-0000",
                                  "role": "CUSTOMER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "phone-copycat@popq.test",
                                  "password": "password1",
                                  "name": "번호도용자",
                                  "phone": "01070000000",
                                  "role": "CUSTOMER"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DUPLICATE_PHONE"));
    }

    @Test
    void signUpRejectsMissingPhone() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "no-phone@popq.test",
                                  "password": "password1",
                                  "name": "전화번호 없음",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"));
    }

    @Test
    void signUpRejectsInvalidPhoneFormat() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "bad-phone@popq.test",
                                  "password": "password1",
                                  "name": "전화번호 형식 오류",
                                  "phone": "not-a-phone",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"));
    }

    @Test
    void findIdReturnsMaskedEmailForMatchingNameAndPhone() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "find-id-target@popq.test",
                                  "password": "password1",
                                  "name": "아이디찾기대상",
                                  "phone": "010-4444-4444",
                                  "role": "CUSTOMER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/find-id")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "아이디찾기대상",
                                  "phone": "010-4444-4444"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.maskedEmail").value("fi***@popq.test"));
    }

    @Test
    void findIdRejectsMismatchedNameAndPhone() throws Exception {
        mockMvc.perform(post("/api/v1/auth/find-id")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "존재하지않는사용자",
                                  "phone": "010-9999-9999"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("IDENTITY_VERIFICATION_FAILED"));
    }

    @Test
    void passwordResetVerifyAndConfirmChangesPassword() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-target@popq.test",
                                  "password": "oldpassword1",
                                  "name": "비번찾기대상",
                                  "phone": "010-5555-5555",
                                  "role": "CUSTOMER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/password-reset/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-target@popq.test",
                                  "phone": "010-5555-5555"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.success").value(true));

        mockMvc.perform(post("/api/v1/auth/password-reset/confirm")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-target@popq.test",
                                  "phone": "010-5555-5555",
                                  "newPassword": "newpassword1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.success").value(true));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-target@popq.test",
                                  "password": "newpassword1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-target@popq.test",
                                  "password": "oldpassword1"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void passwordResetVerifyRejectsMismatchedPhone() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-mismatch@popq.test",
                                  "password": "password1",
                                  "name": "불일치 테스트",
                                  "phone": "010-6666-6666",
                                  "role": "CUSTOMER"
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/password-reset/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reset-mismatch@popq.test",
                                  "phone": "010-0000-0000"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("IDENTITY_VERIFICATION_FAILED"));
    }
}
