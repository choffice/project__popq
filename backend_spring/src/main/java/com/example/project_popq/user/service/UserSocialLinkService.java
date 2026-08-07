package com.example.project_popq.user.service;

import com.example.project_popq.auth.social.GoogleIdTokenVerifier;
import com.example.project_popq.auth.social.GoogleIdentity;
import com.example.project_popq.auth.social.KakaoAccessTokenVerifier;
import com.example.project_popq.auth.social.KakaoIdentity;
import com.example.project_popq.auth.social.NaverAccessTokenVerifier;
import com.example.project_popq.auth.social.NaverIdentity;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.SocialAccount;
import com.example.project_popq.user.domain.SocialProvider;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.SocialAccountRepository;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserSocialLinkService {

    private final UserRepository userRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final GoogleIdTokenVerifier googleIdTokenVerifier;
    private final KakaoAccessTokenVerifier kakaoAccessTokenVerifier;
    private final NaverAccessTokenVerifier naverAccessTokenVerifier;

    @Transactional
    public void link(
            Long userId,
            PlatformRole activeRole,
            SocialProvider provider,
            String providerToken
    ) {
        String providerUserId = resolveProviderUserId(
                provider,
                providerToken,
                activeRole
        );

        var existing = socialAccountRepository
                .findByProviderAndProviderUserId(provider, providerUserId);

        if (existing.isPresent()) {
            if (!existing.get().getUser().getId().equals(userId)) {
                throw new BusinessException(
                        ErrorCode.SOCIAL_ACCOUNT_ALREADY_LINKED
                );
            }
            return;
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));

        socialAccountRepository.save(
                SocialAccount.create(user, provider, providerUserId)
        );
    }

    private String resolveProviderUserId(
            SocialProvider provider,
            String providerToken,
            PlatformRole activeRole
    ) {
        try {
            return switch (provider) {
                case GOOGLE -> verifyGoogle(providerToken);
                case KAKAO -> verifyKakao(providerToken, activeRole);
                case NAVER -> verifyNaver(providerToken);
                default -> throw new BusinessException(ErrorCode.INVALID_REQUEST);
            };
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.INVALID_SOCIAL_TOKEN);
        }
    }

    private String verifyGoogle(String idToken) {
        GoogleIdentity identity = googleIdTokenVerifier.verify(idToken);
        if (!identity.emailVerified()) {
            throw new BusinessException(ErrorCode.INVALID_SOCIAL_TOKEN);
        }
        return identity.providerUserId();
    }

    private String verifyKakao(String accessToken, PlatformRole activeRole) {
        KakaoIdentity identity = kakaoAccessTokenVerifier.verify(
                accessToken,
                activeRole
        );
        return identity.providerUserId();
    }

    private String verifyNaver(String accessToken) {
        NaverIdentity identity = naverAccessTokenVerifier.verify(accessToken);
        return identity.providerUserId();
    }
}
