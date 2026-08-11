package com.example.project_popq.auth.service;

import com.example.project_popq.auth.config.JwtProperties;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class JwtTokenService {

    private static final String ACCESS_TOKEN_TYPE = "access";
    private static final String REFRESH_TOKEN_TYPE = "refresh";
    private static final String REFRESH_ISSUER_SUFFIX = "-refresh";

    private final JwtEncoder jwtEncoder;
    private final JwtProperties properties;

    public IssuedAccessToken issueAccessToken(User user) {
        return issueAccessToken(
            user,
            user.getRole()
        );
    }

    public IssuedAccessToken issueAccessToken(
        User user,
        PlatformRole activeRole
    ) {
        Instant issuedAt = Instant.now();

        Instant expiresAt = issuedAt.plus(
            properties.accessTokenExpiration()
        );

        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(properties.issuer())
            .issuedAt(issuedAt)
            .expiresAt(expiresAt)
            .subject(user.getId().toString())
            .claim(
                "email",
                user.getEmail()
            )
            .claim(
                "name",
                user.getName()
            )
            .claim(
                "role",
                activeRole.name()
            )
            .claim(
                "token_type",
                ACCESS_TOKEN_TYPE
            )
            .build();

        String token = encode(claims);

        return new IssuedAccessToken(
            token,
            properties
                .accessTokenExpiration()
                .toSeconds()
        );
    }

    public IssuedRefreshToken issueRefreshToken(
        User user
    ) {
        return issueRefreshToken(
            user,
            user.getRole()
        );
    }

    public IssuedRefreshToken issueRefreshToken(
        User user,
        PlatformRole activeRole
    ) {
        Instant issuedAt = Instant.now();

        Instant expiresAt = issuedAt.plus(
            properties.refreshTokenExpiration()
        );

        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(refreshIssuer())
            .issuedAt(issuedAt)
            .expiresAt(expiresAt)
            .subject(user.getId().toString())
            .claim(
                "role",
                activeRole.name()
            )
            .claim(
                "token_type",
                REFRESH_TOKEN_TYPE
            )
            .claim(
                "jti",
                UUID.randomUUID().toString()
            )
            .build();

        String token = encode(claims);

        return new IssuedRefreshToken(
            token,
            properties
                .refreshTokenExpiration()
                .toSeconds()
        );
    }

    public String refreshIssuer() {
        return properties.issuer()
            + REFRESH_ISSUER_SUFFIX;
    }

    private String encode(
        JwtClaimsSet claims
    ) {
        JwsHeader header = JwsHeader
            .with(MacAlgorithm.HS256)
            .build();

        return jwtEncoder.encode(
            JwtEncoderParameters.from(
                header,
                claims
            )
        ).getTokenValue();
    }

    public record IssuedAccessToken(
        String value,
        long expiresInSeconds
    ) {
    }

    public record IssuedRefreshToken(
        String value,
        long expiresInSeconds
    ) {
    }
}