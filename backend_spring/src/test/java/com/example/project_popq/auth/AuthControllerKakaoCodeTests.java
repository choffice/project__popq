package com.example.project_popq.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.project_popq.auth.controller.AuthController;
import com.example.project_popq.auth.dto.KakaoCodeLoginRequest;
import com.example.project_popq.auth.service.AuthService;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.auth.service.EmailVerificationService;
import com.example.project_popq.auth.service.SocialAuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class AuthControllerKakaoCodeTests {

  private SocialAuthService socialAuthService;
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    socialAuthService = mock(SocialAuthService.class);

    AuthController controller = new AuthController(
        mock(CurrentUserService.class),
        mock(AuthService.class),
        socialAuthService,
        mock(EmailVerificationService.class)
    );

    mockMvc = MockMvcBuilders
        .standaloneSetup(controller)
        .build();
  }

  @Test
  void exchangesKakaoCodeForSellerLogin() throws Exception {
    when(socialAuthService.loginWithKakaoCode(any()))
        .thenReturn(null);

    mockMvc.perform(post("/api/v1/auth/social/kakao/code")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "code": "kakao-authorization-code"
                }
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.success").value(true));

    ArgumentCaptor<KakaoCodeLoginRequest> requestCaptor =
        ArgumentCaptor.forClass(KakaoCodeLoginRequest.class);

    verify(socialAuthService).loginWithKakaoCode(
        requestCaptor.capture()
    );

    org.assertj.core.api.Assertions.assertThat(
        requestCaptor.getValue().code()
    ).isEqualTo("kakao-authorization-code");
  }

  @Test
  void rejectsBlankKakaoCode() throws Exception {
    mockMvc.perform(post("/api/v1/auth/social/kakao/code")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "code": ""
                }
                """))
        .andExpect(status().isBadRequest());
  }
}
