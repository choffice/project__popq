package com.example.project_popq.auth.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.auth.dto.SignupRequest;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class AuthServiceTests {

    @Mock
    private UserRepository userRepository;

    @Mock
    private SellerProfileRepository sellerProfileRepository;

    @Mock
    private JwtTokenService jwtTokenService;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private EmailVerificationService emailVerificationService;

    @InjectMocks
    private AuthService authService;

    @Test
    void publicSignupRejectsAdminRoleBeforePersistingUser() {
        SignupRequest request = new SignupRequest(
                "public-admin@popq.test",
                "password1",
                "공개 관리자",
                "010-1234-9876",
                PlatformRole.ADMIN,
                null
        );

        assertThatThrownBy(() -> authService.signup(request))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_SIGNUP_ROLE);
    }
}
