package com.example.project_popq.auth.service;

import com.example.project_popq.auth.dto.AuthUserResponse;
import com.example.project_popq.auth.dto.DevLoginRequest;
import com.example.project_popq.auth.dto.DevLoginResponse;
import com.example.project_popq.auth.service.JwtTokenService.IssuedAccessToken;
import com.example.project_popq.auth.service.JwtTokenService.IssuedRefreshToken;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DevAuthService {

    private final UserRepository userRepository;
    private final SellerProfileRepository sellerProfileRepository;
    private final JwtTokenService jwtTokenService;

    @Transactional
    public DevLoginResponse login(DevLoginRequest request) {
        validateRole(request.role());

        String normalizedEmail = request
            .email()
            .trim()
            .toLowerCase();

        User user = userRepository
            .findByEmailIgnoreCase(normalizedEmail)
            .orElseGet(
                () -> createUser(
                    request,
                    normalizedEmail
                )
            );

        if (!user.isActive()) {
            throw new BusinessException(
                ErrorCode.USER_INACTIVE
            );
        }

        user.addRole(request.role());

        ensureSellerProfile(
            user,
            request.role()
        );

        IssuedAccessToken accessToken =
            jwtTokenService.issueAccessToken(
                user,
                request.role()
            );

        IssuedRefreshToken refreshToken =
            jwtTokenService.issueRefreshToken(
                user,
                request.role()
            );

        return new DevLoginResponse(
            accessToken.value(),
            refreshToken.value(),
            "Bearer",
            accessToken.expiresInSeconds(),
            AuthUserResponse.from(
                user,
                request.role()
            )
        );
    }

    private User createUser(
        DevLoginRequest request,
        String normalizedEmail
    ) {
        User created = User.create(
            normalizedEmail,
            request.name().trim(),
            request.role()
        );

        return userRepository.save(created);
    }

    private void ensureSellerProfile(
        User user,
        PlatformRole activeRole
    ) {
        if (activeRole == PlatformRole.SELLER
            && sellerProfileRepository
            .findByUserId(user.getId())
            .isEmpty()) {

            sellerProfileRepository.save(
                SellerProfile.createPending(user)
            );
        }
    }

    private void validateRole(
        PlatformRole role
    ) {
        if (role == PlatformRole.ADMIN) {
            throw new BusinessException(
                ErrorCode.INVALID_DEV_ROLE
            );
        }
    }
}