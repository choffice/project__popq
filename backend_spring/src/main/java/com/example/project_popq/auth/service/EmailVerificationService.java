package com.example.project_popq.auth.service;

import com.example.project_popq.auth.domain.EmailVerificationChallenge;
import com.example.project_popq.auth.domain.EmailVerificationPurpose;
import com.example.project_popq.auth.dto.EmailVerificationConfirmRequest;
import com.example.project_popq.auth.dto.EmailVerificationConfirmResponse;
import com.example.project_popq.auth.dto.EmailVerificationSendRequest;
import com.example.project_popq.auth.dto.EmailVerificationSendResponse;
import com.example.project_popq.auth.repository.EmailVerificationChallengeRepository;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.user.repository.UserRepository;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EmailVerificationService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final EmailVerificationChallengeRepository challengeRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JavaMailSender mailSender;
    private final boolean required;
    private final String fromAddress;
    private final Duration codeTtl;
    private final Duration resendInterval;
    private final int maxAttempts;

    public EmailVerificationService(
            EmailVerificationChallengeRepository challengeRepository,
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JavaMailSender mailSender,
            @Value("${popq.auth.email-verification.required:true}") boolean required,
            @Value("${popq.auth.email-verification.from:}") String fromAddress,
            @Value("${popq.auth.email-verification.code-ttl:PT10M}") Duration codeTtl,
            @Value("${popq.auth.email-verification.resend-interval:PT1M}") Duration resendInterval,
            @Value("${popq.auth.email-verification.max-attempts:5}") int maxAttempts
    ) {
        this.challengeRepository = challengeRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.mailSender = mailSender;
        this.required = required;
        this.fromAddress = fromAddress;
        this.codeTtl = codeTtl;
        this.resendInterval = resendInterval;
        this.maxAttempts = maxAttempts;
    }

    @Transactional
    public EmailVerificationSendResponse sendSignupCode(EmailVerificationSendRequest request) {
        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new BusinessException(ErrorCode.DUPLICATE_USER);
        }

        Instant now = Instant.now();
        String code = String.format(Locale.ROOT, "%06d", SECURE_RANDOM.nextInt(1_000_000));
        String codeHash = passwordEncoder.encode(code);
        Instant expiresAt = now.plus(codeTtl);

        EmailVerificationChallenge challenge = challengeRepository
                .findForUpdate(email, EmailVerificationPurpose.SIGNUP)
                .map(existing -> {
                    if (!existing.canResend(now, resendInterval)) {
                        throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_RATE_LIMITED);
                    }
                    existing.resend(codeHash, now, expiresAt);
                    return existing;
                })
                .orElseGet(() -> EmailVerificationChallenge.createForSignup(
                        email,
                        codeHash,
                        now,
                        expiresAt
                ));

        challengeRepository.save(challenge);
        sendCodeEmail(email, code);

        return new EmailVerificationSendResponse(
                codeTtl.toSeconds(),
                resendInterval.toSeconds()
        );
    }

    @Transactional(noRollbackFor = BusinessException.class)
    public EmailVerificationConfirmResponse verifySignupCode(
            EmailVerificationConfirmRequest request
    ) {
        String email = normalizeEmail(request.email());
        EmailVerificationChallenge challenge = findRequiredForUpdate(email);
        Instant now = Instant.now();

        if (challenge.isExpired(now)) {
            throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_EXPIRED);
        }
        if (challenge.hasExceededAttempts(maxAttempts)) {
            throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_ATTEMPTS_EXCEEDED);
        }
        if (!passwordEncoder.matches(request.code(), challenge.getCodeHash())) {
            challenge.registerFailedAttempt();
            if (challenge.hasExceededAttempts(maxAttempts)) {
                throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_ATTEMPTS_EXCEEDED);
            }
            throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_INVALID);
        }

        String verificationToken = UUID.randomUUID().toString();
        challenge.verify(passwordEncoder.encode(verificationToken), now);
        return new EmailVerificationConfirmResponse(verificationToken);
    }

    @Transactional
    public void consumeSignupVerification(String emailValue, String verificationToken) {
        if (!required) {
            return;
        }
        if (verificationToken == null || verificationToken.isBlank()) {
            throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_REQUIRED);
        }

        String email = normalizeEmail(emailValue);
        EmailVerificationChallenge challenge = findRequiredForUpdate(email);
        Instant now = Instant.now();

        if (challenge.isExpired(now)) {
            throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_EXPIRED);
        }
        if (!challenge.isVerified()
                || challenge.isConsumed()
                || !passwordEncoder.matches(
                verificationToken,
                challenge.getVerificationTokenHash()
        )) {
            throw new BusinessException(ErrorCode.EMAIL_VERIFICATION_REQUIRED);
        }

        challenge.consume(now);
    }

    private EmailVerificationChallenge findRequiredForUpdate(String email) {
        return challengeRepository
                .findForUpdate(email, EmailVerificationPurpose.SIGNUP)
                .orElseThrow(() -> new BusinessException(ErrorCode.EMAIL_VERIFICATION_REQUIRED));
    }

    private void sendCodeEmail(String email, String code) {
        SimpleMailMessage message = new SimpleMailMessage();
        if (!fromAddress.isBlank()) {
            message.setFrom(fromAddress);
        }
        message.setTo(email);
        message.setSubject("[POPQ] 회원가입 이메일 인증번호");
        message.setText("POPQ 회원가입 인증번호는 " + code + "입니다.\n"
                + "인증번호는 " + codeTtl.toMinutes() + "분 동안 유효합니다.");
        try {
            mailSender.send(message);
        } catch (MailException exception) {
            throw new BusinessException(ErrorCode.EMAIL_DELIVERY_FAILED);
        }
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
