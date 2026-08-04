package com.example.project_popq.auth.service;

import com.example.project_popq.auth.dto.AuthTokenResponse;
import com.example.project_popq.auth.dto.AuthUserResponse;
import com.example.project_popq.auth.dto.SocialLoginRequest;
import com.example.project_popq.auth.service.JwtTokenService.IssuedAccessToken;
import com.example.project_popq.auth.social.GoogleIdTokenVerifier;
import com.example.project_popq.auth.social.GoogleIdentity;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.SocialAccount;
import com.example.project_popq.user.domain.SocialProvider;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.SocialAccountRepository;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SocialAuthService {

  private final UserRepository userRepository;
  private final SocialAccountRepository socialAccountRepository;
  private final SellerProfileRepository sellerProfileRepository;
  private final GoogleIdTokenVerifier googleIdTokenVerifier;
  private final JwtTokenService jwtTokenService;

  @Transactional
  public AuthTokenResponse login(SocialLoginRequest request) {
    validateRole(request.role());

    if (request.provider() != SocialProvider.GOOGLE) {
      throw new BusinessException(ErrorCode.INVALID_REQUEST);
    }

    GoogleIdentity identity = verifyGoogleToken(
        request.providerToken()
    );

    User user = findOrCreateGoogleUser(
        identity,
        request.role()
    );

    validateUser(user, request.role());
    ensureSellerProfile(user);

    return issueToken(user);
  }

  private GoogleIdentity verifyGoogleToken(String idToken) {
    try {
      GoogleIdentity identity =
          googleIdTokenVerifier.verify(idToken);

      if (!identity.emailVerified()) {
        throw new BusinessException(
            ErrorCode.INVALID_SOCIAL_TOKEN
        );
      }

      return identity;
    } catch (JwtException | IllegalArgumentException exception) {
      throw new BusinessException(
          ErrorCode.INVALID_SOCIAL_TOKEN
      );
    }
  }

  private User findOrCreateGoogleUser(
      GoogleIdentity identity,
      PlatformRole requestedRole
  ) {
    return socialAccountRepository
        .findByProviderAndProviderUserId(
            SocialProvider.GOOGLE,
            identity.providerUserId()
        )
        .map(SocialAccount::getUser)
        .orElseGet(() -> linkOrCreateGoogleUser(
            identity,
            requestedRole
        ));
  }

  private User linkOrCreateGoogleUser(
      GoogleIdentity identity,
      PlatformRole requestedRole
  ) {
    String normalizedEmail =
        identity.email().trim().toLowerCase();

    User user = userRepository
        .findByEmailIgnoreCase(normalizedEmail)
        .orElseGet(() -> userRepository.save(
            User.create(
                normalizedEmail,
                identity.name().trim(),
                requestedRole
            )
        ));

    if (user.getRole() != requestedRole) {
      throw new BusinessException(
          ErrorCode.SOCIAL_ROLE_MISMATCH
      );
    }

    socialAccountRepository.save(
        SocialAccount.create(
            user,
            SocialProvider.GOOGLE,
            identity.providerUserId()
        )
    );

    return user;
  }

  private void validateUser(
      User user,
      PlatformRole requestedRole
  ) {
    if (!user.isActive()) {
      throw new BusinessException(ErrorCode.USER_INACTIVE);
    }

    if (user.getRole() != requestedRole) {
      throw new BusinessException(
          ErrorCode.SOCIAL_ROLE_MISMATCH
      );
    }
  }

  private void validateRole(PlatformRole role) {
    if (role != PlatformRole.CUSTOMER
        && role != PlatformRole.SELLER) {
      throw new BusinessException(ErrorCode.INVALID_REQUEST);
    }
  }

  private void ensureSellerProfile(User user) {
    if (user.getRole() == PlatformRole.SELLER
        && sellerProfileRepository
        .findByUserId(user.getId())
        .isEmpty()) {
      sellerProfileRepository.save(
          SellerProfile.createPending(user)
      );
    }
  }

  private AuthTokenResponse issueToken(User user) {
    IssuedAccessToken accessToken =
        jwtTokenService.issueAccessToken(user);

    return new AuthTokenResponse(
        accessToken.value(),
        "Bearer",
        accessToken.expiresInSeconds(),
        AuthUserResponse.from(user)
    );
  }
}