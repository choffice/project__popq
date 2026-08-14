package com.example.project_popq.auth.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.auth.domain.EmailVerificationChallenge;
import com.example.project_popq.auth.domain.EmailVerificationPurpose;
import com.example.project_popq.auth.dto.EmailVerificationConfirmRequest;
import com.example.project_popq.auth.dto.EmailVerificationConfirmResponse;
import com.example.project_popq.auth.dto.EmailVerificationSendRequest;
import com.example.project_popq.auth.repository.EmailVerificationChallengeRepository;
import com.example.project_popq.user.repository.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class EmailVerificationServiceTests {

    @Mock
    private EmailVerificationChallengeRepository challengeRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JavaMailSender mailSender;

    private EmailVerificationService service;

    @BeforeEach
    void setUp() {
        service = new EmailVerificationService(
                challengeRepository,
                userRepository,
                passwordEncoder,
                mailSender,
                true,
                "no-reply@popq.test",
                Duration.ofMinutes(10),
                Duration.ofMinutes(1),
                5
        );
    }

    @Test
    void sendsSignupVerificationCode() {
        when(userRepository.existsByEmailIgnoreCase("user@popq.test")).thenReturn(false);
        when(challengeRepository.findForUpdate(
                "user@popq.test",
                EmailVerificationPurpose.SIGNUP
        )).thenReturn(Optional.empty());
        when(passwordEncoder.encode(anyString())).thenReturn("code-hash");

        service.sendSignupCode(new EmailVerificationSendRequest("USER@popq.test"));

        verify(challengeRepository).save(any(EmailVerificationChallenge.class));
        verify(mailSender).send(any(SimpleMailMessage.class));
    }

    @Test
    void verifiesCodeAndConsumesIssuedToken() {
        Instant now = Instant.now();
        EmailVerificationChallenge challenge = EmailVerificationChallenge.createForSignup(
                "user@popq.test",
                "code-hash",
                now,
                now.plus(Duration.ofMinutes(10))
        );
        when(challengeRepository.findForUpdate(
                "user@popq.test",
                EmailVerificationPurpose.SIGNUP
        )).thenReturn(Optional.of(challenge));
        when(passwordEncoder.matches("123456", "code-hash")).thenReturn(true);
        when(passwordEncoder.encode(anyString())).thenReturn("token-hash");

        EmailVerificationConfirmResponse response = service.verifySignupCode(
                new EmailVerificationConfirmRequest("user@popq.test", "123456")
        );
        when(passwordEncoder.matches(response.verificationToken(), "token-hash"))
                .thenReturn(true);

        service.consumeSignupVerification("user@popq.test", response.verificationToken());

        assertThat(challenge.isVerified()).isTrue();
        assertThat(challenge.isConsumed()).isTrue();
    }
}
