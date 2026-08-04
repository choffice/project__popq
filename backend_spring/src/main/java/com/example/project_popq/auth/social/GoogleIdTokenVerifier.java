package com.example.project_popq.auth.social;

import com.example.project_popq.auth.config.GoogleOAuthProperties;
import java.util.List;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

@Component
public class GoogleIdTokenVerifier {

  private static final String GOOGLE_JWK_SET_URI =
      "https://www.googleapis.com/oauth2/v3/certs";

  private final String clientId;
  private final JwtDecoder jwtDecoder;

  public GoogleIdTokenVerifier(GoogleOAuthProperties properties) {
    this.clientId = properties.clientId();

    NimbusJwtDecoder decoder = NimbusJwtDecoder
        .withJwkSetUri(GOOGLE_JWK_SET_URI)
        .build();

    OAuth2TokenValidator<Jwt> validator =
        new DelegatingOAuth2TokenValidator<>(
            new JwtTimestampValidator(),
            this::validateGoogleClaims
        );

    decoder.setJwtValidator(validator);
    this.jwtDecoder = decoder;
  }

  public GoogleIdentity verify(String idToken) {
    Jwt jwt = jwtDecoder.decode(idToken);

    String providerUserId = jwt.getSubject();
    String email = jwt.getClaimAsString("email");
    String name = jwt.getClaimAsString("name");
    boolean emailVerified =
        Boolean.TRUE.equals(jwt.getClaim("email_verified"));

    if (providerUserId == null || providerUserId.isBlank()) {
      throw new IllegalArgumentException(
          "Google token does not contain subject"
      );
    }

    if (email == null || email.isBlank()) {
      throw new IllegalArgumentException(
          "Google token does not contain email"
      );
    }

    if (name == null || name.isBlank()) {
      name = email;
    }

    return new GoogleIdentity(
        providerUserId,
        email,
        name,
        emailVerified
    );
  }

  private OAuth2TokenValidatorResult validateGoogleClaims(Jwt jwt) {
    String issuer = jwt.getIssuer() == null
        ? null
        : jwt.getIssuer().toString();

    boolean validIssuer =
        "https://accounts.google.com".equals(issuer)
            || "accounts.google.com".equals(issuer);

    List<String> audience = jwt.getAudience();
    boolean validAudience =
        audience != null && audience.contains(clientId);

    if (!validIssuer) {
      return failure("Invalid Google token issuer");
    }

    if (!validAudience) {
      return failure("Invalid Google token audience");
    }

    return OAuth2TokenValidatorResult.success();
  }

  private OAuth2TokenValidatorResult failure(String description) {
    OAuth2Error error = new OAuth2Error(
        "invalid_token",
        description,
        null
    );
    return OAuth2TokenValidatorResult.failure(error);
  }
}