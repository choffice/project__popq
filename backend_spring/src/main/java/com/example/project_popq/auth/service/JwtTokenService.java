package com.example.project_popq.auth.service;

import com.example.project_popq.auth.config.JwtProperties;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Service;
import com.example.project_popq.user.domain.PlatformRole;

@Service
@RequiredArgsConstructor
public class JwtTokenService {

    private final JwtEncoder jwtEncoder;
    private final JwtProperties properties;

    public IssuedAccessToken issueAccessToken(User user) {
        return issueAccessToken(user, user.getRole());
    }

    public IssuedAccessToken issueAccessToken(
        User user,
        PlatformRole activeRole
    ) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plus(properties.accessTokenExpiration());
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(properties.issuer())
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .subject(user.getId().toString())
                .claim("email", user.getEmail())
                .claim("name", user.getName())
                .claim("role", activeRole.name())
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = jwtEncoder.encode(JwtEncoderParameters.from(header, claims))
                .getTokenValue();
        return new IssuedAccessToken(
                token,
                properties.accessTokenExpiration().toSeconds()
        );
    }

    public record IssuedAccessToken(String value, long expiresInSeconds) {
    }
}
