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
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.example.project_popq.auth.social.KakaoAccessTokenVerifier;
import com.example.project_popq.auth.social.KakaoIdentity;
import com.example.project_popq.auth.social.NaverAccessTokenVerifier;
import com.example.project_popq.auth.social.NaverIdentity;
import com.example.project_popq.auth.service.JwtTokenService.IssuedRefreshToken;

@Service
@RequiredArgsConstructor
public class SocialAuthService {

  private final UserRepository userRepository;
  private final SocialAccountRepository socialAccountRepository;
  private final SellerProfileRepository sellerProfileRepository;
  private final GoogleIdTokenVerifier googleIdTokenVerifier;
  private final KakaoAccessTokenVerifier kakaoAccessTokenVerifier;
  private final NaverAccessTokenVerifier naverAccessTokenVerifier;
  private final JwtTokenService jwtTokenService;


  @Transactional
  public AuthTokenResponse login(SocialLoginRequest request) {
    validateRole(request.role());

    if (request.provider() == SocialProvider.KAKAO) {
      return loginWithKakao(request);
    }

    if (request.provider() == SocialProvider.NAVER) {
      return loginWithNaver(request);
    }

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

    validateUser(user);

    user.addRole(request.role());

    ensureSellerProfile(user, request.role());

    return issueToken(user, request.role());
  }

  private AuthTokenResponse loginWithKakao(
      SocialLoginRequest request
  ) {
    KakaoIdentity identity = verifyKakaoToken(
        request.providerToken(),
        request.role()
    );

    User user = findOrCreateKakaoUser(
        identity,
        request.role()
    );

    validateUser(user);

    user.addRole(request.role());

    ensureSellerProfile(user, request.role());

    return issueToken(user, request.role());
  }

  private AuthTokenResponse loginWithNaver(
      SocialLoginRequest request
  ) {
    NaverIdentity identity = verifyNaverToken(
        request.providerToken()
    );

    User user = findOrCreateNaverUser(
        identity,
        request.role()
    );

    validateUser(user);

    user.addRole(request.role());

    ensureSellerProfile(user, request.role());

    return issueToken(user, request.role());
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
      System.err.println(
          "Google token verification failed: "
              + exception.getMessage()
      );
      exception.printStackTrace();

      throw new BusinessException(
          ErrorCode.INVALID_SOCIAL_TOKEN
      );
    }
  }

  private KakaoIdentity verifyKakaoToken(
      String accessToken,
      PlatformRole requestedRole
  ) {
    try {
      return kakaoAccessTokenVerifier.verify(
          accessToken,
          requestedRole
      );
    } catch (IllegalArgumentException exception) {
      throw new BusinessException(
          ErrorCode.INVALID_SOCIAL_TOKEN
      );
    }
  }

  private NaverIdentity verifyNaverToken(
      String accessToken
  ) {
    try {
      return naverAccessTokenVerifier.verify(
          accessToken
      );
    } catch (IllegalArgumentException exception) {
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

  private User findOrCreateKakaoUser(
      KakaoIdentity identity,
      PlatformRole requestedRole
  ) {
    return socialAccountRepository
        .findByProviderAndProviderUserId(
            SocialProvider.KAKAO,
            identity.providerUserId()
        )
        .map(SocialAccount::getUser)
        .orElseGet(() -> linkOrCreateKakaoUser(
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

    socialAccountRepository.save(
        SocialAccount.create(
            user,
            SocialProvider.GOOGLE,
            identity.providerUserId()
        )
    );

    return user;
  }

  private User findOrCreateNaverUser(
      NaverIdentity identity,
      PlatformRole requestedRole
  ) {
    return socialAccountRepository
        .findByProviderAndProviderUserId(
            SocialProvider.NAVER,
            identity.providerUserId()
        )
        .map(SocialAccount::getUser)
        .orElseGet(() -> linkOrCreateNaverUser(
            identity,
            requestedRole
        ));
  }

  private User linkOrCreateKakaoUser(
      KakaoIdentity identity,
      PlatformRole requestedRole
  ) {
    String normalizedEmail = identity.email();

    if (normalizedEmail == null
        || normalizedEmail.isBlank()) {
      normalizedEmail = (
          "kakao_"
              + identity.providerUserId()
              .replace(":", "_")
              + "@social.popq.local"
      ).toLowerCase();
    } else {
      normalizedEmail =
          normalizedEmail.trim().toLowerCase();
    }


    String name = identity.name();

    if (name == null || name.isBlank()) {
      name = "카카오 사용자";
    } else {
      name = name.trim();
    }

    String finalEmail = normalizedEmail;
    String finalName = name;

    User user = userRepository
        .findByEmailIgnoreCase(finalEmail)
        .orElseGet(() -> userRepository.save(
            User.create(
                finalEmail,
                finalName,
                requestedRole
            )
        ));

    socialAccountRepository.save(
        SocialAccount.create(
            user,
            SocialProvider.KAKAO,
            identity.providerUserId()
        )
    );

    return user;
  }

  private User linkOrCreateNaverUser(
      NaverIdentity identity,
      PlatformRole requestedRole
  ) {
    String normalizedEmail = identity.email();

    if (normalizedEmail == null
        || normalizedEmail.isBlank()) {
      String safeProviderUserId =
          identity.providerUserId()
              .replaceAll(
                  "[^A-Za-z0-9]",
                  "_"
              );

      normalizedEmail = (
          "naver_"
              + safeProviderUserId
              + "@social.popq.local"
      ).toLowerCase();
    } else {
      normalizedEmail =
          normalizedEmail.trim().toLowerCase();
    }

    String name = identity.name();

    if (name == null || name.isBlank()) {
      name = "네이버 사용자";
    } else {
      name = name.trim();
    }

    String finalEmail = normalizedEmail;
    String finalName = name;

    User user = userRepository
        .findByEmailIgnoreCase(finalEmail)
        .orElseGet(() -> userRepository.save(
            User.create(
                finalEmail,
                finalName,
                requestedRole
            )
        ));

    socialAccountRepository.save(
        SocialAccount.create(
            user,
            SocialProvider.NAVER,
            identity.providerUserId()
        )
    );

    return user;
  }

  private void validateUser(User user) {
    user.reconcileWithdrawalState(Instant.now());
    if (!user.isActive()) {
      throw new BusinessException(
          ErrorCode.USER_INACTIVE
      );
    }
  }

  private void validateRole(PlatformRole role) {
    if (role != PlatformRole.CUSTOMER
        && role != PlatformRole.SELLER) {
      throw new BusinessException(ErrorCode.INVALID_REQUEST);
    }
  }

  private void ensureSellerProfile(User user, PlatformRole activeRole) {
    if (activeRole == PlatformRole.SELLER
        && sellerProfileRepository
        .findByUserId(user.getId())
        .isEmpty()) {
      sellerProfileRepository.save(
          SellerProfile.createPending(user)
      );
    }
  }

  private AuthTokenResponse issueToken(User user, PlatformRole activeRole) {
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
}