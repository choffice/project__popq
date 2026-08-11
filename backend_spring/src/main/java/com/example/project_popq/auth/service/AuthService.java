package com.example.project_popq.auth.service;

import com.example.project_popq.auth.dto.AckResponse;
import com.example.project_popq.auth.dto.AuthTokenResponse;
import com.example.project_popq.auth.dto.AuthUserResponse;
import com.example.project_popq.auth.dto.FindIdRequest;
import com.example.project_popq.auth.dto.FindIdResponse;
import com.example.project_popq.auth.dto.LoginRequest;
import com.example.project_popq.auth.dto.PasswordResetConfirmRequest;
import com.example.project_popq.auth.dto.PasswordResetVerifyRequest;
import com.example.project_popq.auth.dto.RefreshTokenRequest;
import com.example.project_popq.auth.dto.SignupRequest;
import com.example.project_popq.auth.service.JwtTokenService.IssuedAccessToken;
import com.example.project_popq.auth.service.JwtTokenService.IssuedRefreshToken;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;

import java.time.Instant;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final SellerProfileRepository sellerProfileRepository;
    private final JwtTokenService jwtTokenService;
    private final PasswordEncoder passwordEncoder;
    private final JwtDecoder refreshJwtDecoder;

    public AuthService(
        UserRepository userRepository,
        SellerProfileRepository sellerProfileRepository,
        JwtTokenService jwtTokenService,
        PasswordEncoder passwordEncoder,
        @Qualifier("refreshJwtDecoder")
        JwtDecoder refreshJwtDecoder
    ) {
        this.userRepository = userRepository;
        this.sellerProfileRepository = sellerProfileRepository;
        this.jwtTokenService = jwtTokenService;
        this.passwordEncoder = passwordEncoder;
        this.refreshJwtDecoder = refreshJwtDecoder;
    }

    @Transactional
    public AuthTokenResponse signup(SignupRequest request) {
        if (request.role() == PlatformRole.ADMIN) {
            throw new BusinessException(
                ErrorCode.INVALID_SIGNUP_ROLE
            );
        }

        String normalizedEmail = request
            .email()
            .trim()
            .toLowerCase();

        if (userRepository.existsByEmailIgnoreCase(
            normalizedEmail
        )) {
            throw new BusinessException(
                ErrorCode.DUPLICATE_USER
            );
        }

        String normalizedPhone = normalizePhone(
            request.phone()
        );

        if (userRepository.existsByPhone(
            normalizedPhone
        )) {
            throw new BusinessException(
                ErrorCode.DUPLICATE_PHONE
            );
        }

        User user = User.createWithPassword(
            normalizedEmail,
            request.name().trim(),
            normalizedPhone,
            request.role(),
            passwordEncoder.encode(
                request.password()
            )
        );

        user = userRepository.save(user);

        ensureSellerProfile(user);

        return issueToken(user);
    }

    @Transactional
    public AuthTokenResponse login(
        LoginRequest request
    ) {
        String normalizedEmail = request
            .email()
            .trim()
            .toLowerCase();

        User user = userRepository
            .findByEmailIgnoreCase(
                normalizedEmail
            )
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.INVALID_CREDENTIALS
                )
            );

        if (user.getPasswordHash() == null
            || !passwordEncoder.matches(
            request.password(),
            user.getPasswordHash()
        )) {
            throw new BusinessException(
                ErrorCode.INVALID_CREDENTIALS
            );
        }

        user.reconcileWithdrawalState(
            Instant.now()
        );

        if (!user.isActive()) {
            throw new BusinessException(
                ErrorCode.USER_INACTIVE
            );
        }

        PlatformRole activeRole =
            request.role() != null
                ? request.role()
                : user.getRole();

        if (!user.hasRole(activeRole)) {
            throw new BusinessException(
                ErrorCode.SOCIAL_ROLE_MISMATCH
            );
        }

        return issueToken(
            user,
            activeRole
        );
    }

    @Transactional(readOnly = true)
    public AuthTokenResponse refresh(
        RefreshTokenRequest request
    ) {
        if (request == null
            || request.refreshToken() == null
            || request.refreshToken().isBlank()) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        Jwt jwt;

        try {
            jwt = refreshJwtDecoder.decode(
                request.refreshToken()
            );
        } catch (JwtException exception) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }
        
        String tokenType = jwt.getClaimAsString(
            "token_type"
        );

        if (!"refresh".equals(tokenType)) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        Long userId;

        try {
            userId = Long.valueOf(
                jwt.getSubject()
            );
        } catch (RuntimeException exception) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        User user = userRepository
            .findById(userId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.INVALID_REFRESH_TOKEN
                )
            );

        if (!user.isActive()) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        Instant issuedAt = jwt.getIssuedAt();

        if (issuedAt == null
            || !user.isTokenValid(issuedAt)) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        String roleClaim = jwt.getClaimAsString(
            "role"
        );

        PlatformRole activeRole;

        try {
            activeRole = PlatformRole.valueOf(
                roleClaim
            );
        } catch (RuntimeException exception) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        if (!user.hasRole(activeRole)) {
            throw new BusinessException(
                ErrorCode.INVALID_REFRESH_TOKEN
            );
        }

        return issueToken(
            user,
            activeRole
        );
    }

    /**
     * 이미 다른 role로 가입된 계정에 SELLER 접근 권한을 추가합니다.
     * (마이페이지의 "팝큐 비즈 연결하기")
     *
     * user는 이 트랜잭션 안에서 직접 조회해야 합니다.
     * 컨트롤러에서 미리 조회해 온 User를 넘기면 detached 상태라
     * roles 변경이 커밋되지 않습니다.
     */
    @Transactional
    public AckResponse connectSellerAccess(
        Long userId
    ) {
        User user = userRepository
            .findById(userId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.USER_NOT_FOUND
                )
            );

        if (!user.isActive()) {
            throw new BusinessException(
                ErrorCode.USER_INACTIVE
            );
        }

        user.addRole(
            PlatformRole.SELLER
        );

        ensureSellerProfile(
            user,
            PlatformRole.SELLER
        );

        return AckResponse.ok();
    }

    /**
     * 이미 다른 role로 가입된 계정에 CUSTOMER 접근 권한을 추가합니다.
     * (판매자 앱 마이페이지의 "팝큐 고객으로도 이용하기")
     */
    @Transactional
    public AckResponse connectCustomerAccess(
        Long userId
    ) {
        User user = userRepository
            .findById(userId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.USER_NOT_FOUND
                )
            );

        if (!user.isActive()) {
            throw new BusinessException(
                ErrorCode.USER_INACTIVE
            );
        }

        user.addRole(
            PlatformRole.CUSTOMER
        );

        return AckResponse.ok();
    }

    /**
     * 회원 탈퇴를 접수합니다.
     */
    @Transactional
    public AckResponse withdraw(
        Long userId,
        String confirmationPhrase
    ) {
        User user = userRepository
            .findById(userId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.USER_NOT_FOUND
                )
            );

        if (!user.isActive()) {
            throw new BusinessException(
                ErrorCode.USER_INACTIVE
            );
        }

        boolean immediate =
            confirmationPhrase != null
                && !confirmationPhrase.isBlank();

        if (immediate
            && !user.matchesWithdrawalConfirmationPhrase(
            confirmationPhrase
        )) {
            throw new BusinessException(
                ErrorCode.WITHDRAWAL_CONFIRMATION_MISMATCH
            );
        }

        user.requestWithdrawal(
            Instant.now()
        );

        if (immediate) {
            user.finalizeWithdrawal();
        }

        return AckResponse.ok();
    }

    @Transactional(readOnly = true)
    public FindIdResponse findId(
        FindIdRequest request
    ) {
        User user = userRepository
            .findByNameAndPhone(
                request.name().trim(),
                normalizePhone(
                    request.phone()
                )
            )
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.IDENTITY_VERIFICATION_FAILED
                )
            );

        return new FindIdResponse(
            maskEmail(
                user.getEmail()
            )
        );
    }

    @Transactional(readOnly = true)
    public AckResponse verifyForPasswordReset(
        PasswordResetVerifyRequest request
    ) {
        findUserForPasswordReset(
            request.email(),
            request.phone()
        );

        return AckResponse.ok();
    }

    @Transactional
    public AckResponse resetPassword(
        PasswordResetConfirmRequest request
    ) {
        User user = findUserForPasswordReset(
            request.email(),
            request.phone()
        );

        user.changePasswordHash(
            passwordEncoder.encode(
                request.newPassword()
            )
        );

        return AckResponse.ok();
    }

    private User findUserForPasswordReset(
        String email,
        String phone
    ) {
        String normalizedEmail = email
            .trim()
            .toLowerCase();

        return userRepository
            .findByEmailIgnoreCaseAndPhone(
                normalizedEmail,
                normalizePhone(phone)
            )
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.IDENTITY_VERIFICATION_FAILED
                )
            );
    }

    private String normalizePhone(
        String phone
    ) {
        return phone
            .trim()
            .replaceAll("-", "");
    }

    private String maskEmail(
        String email
    ) {
        int at = email.indexOf('@');

        String local = email.substring(
            0,
            at
        );

        String domain = email.substring(
            at
        );

        String visible = local.substring(
            0,
            Math.min(
                2,
                local.length()
            )
        );

        return visible
            + "***"
            + domain;
    }

    private AuthTokenResponse issueToken(
        User user
    ) {
        return issueToken(
            user,
            user.getRole()
        );
    }

    private AuthTokenResponse issueToken(
        User user,
        PlatformRole activeRole
    ) {
        IssuedAccessToken accessToken =
            jwtTokenService.issueAccessToken(
                user,
                activeRole
            );

        IssuedRefreshToken refreshToken =
            jwtTokenService.issueRefreshToken(
                user,
                activeRole
            );

        return new AuthTokenResponse(
            accessToken.value(),
            refreshToken.value(),
            "Bearer",
            accessToken.expiresInSeconds(),
            AuthUserResponse.from(
                user,
                activeRole
            )
        );
    }

    private void ensureSellerProfile(
        User user
    ) {
        ensureSellerProfile(
            user,
            user.getRole()
        );
    }

    private void ensureSellerProfile(
        User user,
        PlatformRole activeRole
    ) {
        if (activeRole == PlatformRole.SELLER
            && sellerProfileRepository
            .findByUserId(
                user.getId()
            )
            .isEmpty()) {
            sellerProfileRepository.save(
                SellerProfile.createPending(
                    user
                )
            );
        }
    }
}