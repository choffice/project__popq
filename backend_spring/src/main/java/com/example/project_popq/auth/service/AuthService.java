package com.example.project_popq.auth.service;

import com.example.project_popq.auth.dto.AuthTokenResponse;
import com.example.project_popq.auth.dto.AuthUserResponse;
import com.example.project_popq.auth.dto.LoginRequest;
import com.example.project_popq.auth.dto.SignupRequest;
import com.example.project_popq.auth.service.JwtTokenService.IssuedAccessToken;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final SellerProfileRepository sellerProfileRepository;
    private final JwtTokenService jwtTokenService;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public AuthTokenResponse signup(SignupRequest request) {
        String normalizedEmail = request.email().trim().toLowerCase();
        if (userRepository.existsByEmailIgnoreCase(normalizedEmail)) {
            throw new BusinessException(ErrorCode.DUPLICATE_USER);
        }

        User user = User.createWithPassword(
                normalizedEmail,
                request.name().trim(),
                request.phone() == null || request.phone().isBlank()
                        ? null
                        : request.phone().trim(),
                request.role(),
                passwordEncoder.encode(request.password())
        );
        user = userRepository.save(user);

        ensureSellerProfile(user);

        return issueToken(user);
    }

    @Transactional(readOnly = true)
    public AuthTokenResponse login(LoginRequest request) {
        String normalizedEmail = request.email().trim().toLowerCase();
        User user = userRepository.findByEmailIgnoreCase(normalizedEmail)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_CREDENTIALS));

        if (user.getPasswordHash() == null
                || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }
        if (!user.isActive()) {
            throw new BusinessException(ErrorCode.USER_INACTIVE);
        }

        return issueToken(user);
    }

    private AuthTokenResponse issueToken(User user) {
        IssuedAccessToken accessToken = jwtTokenService.issueAccessToken(user);
        return new AuthTokenResponse(
                accessToken.value(),
                "Bearer",
                accessToken.expiresInSeconds(),
                AuthUserResponse.from(user)
        );
    }

    private void ensureSellerProfile(User user) {
        if (user.getRole() == PlatformRole.SELLER
                && sellerProfileRepository.findByUserId(user.getId()).isEmpty()) {
            sellerProfileRepository.save(SellerProfile.createPending(user));
        }
    }
}
