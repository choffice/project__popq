package com.example.project_popq.auth.config;

import java.nio.charset.StandardCharsets;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

@Configuration
@EnableConfigurationProperties(JwtProperties.class)
public class JwtConfig {

    private static final String REFRESH_ISSUER_SUFFIX =
        "-refresh";

    @Bean
    public SecretKey jwtSecretKey(
        JwtProperties properties
    ) {
        byte[] secret = properties
            .secret()
            .getBytes(
                StandardCharsets.UTF_8
            );

        if (secret.length < 32) {
            throw new IllegalStateException(
                "POPQ JWT secret must be at least 32 bytes"
            );
        }

        return new SecretKeySpec(
            secret,
            "HmacSHA256"
        );
    }

    @Bean
    public JwtEncoder jwtEncoder(
        SecretKey jwtSecretKey
    ) {
        return NimbusJwtEncoder
            .withSecretKey(jwtSecretKey)
            .algorithm(
                MacAlgorithm.HS256
            )
            .build();
    }

    @Primary
    @Bean
    public JwtDecoder jwtDecoder(
        SecretKey jwtSecretKey,
        JwtProperties properties
    ) {
        NimbusJwtDecoder decoder =
            createDecoder(jwtSecretKey);

        decoder.setJwtValidator(
            JwtValidators.createDefaultWithIssuer(
                properties.issuer()
            )
        );

        return decoder;
    }

    @Bean("refreshJwtDecoder")
    public JwtDecoder refreshJwtDecoder(
        SecretKey jwtSecretKey,
        JwtProperties properties
    ) {
        NimbusJwtDecoder decoder =
            createDecoder(jwtSecretKey);

        decoder.setJwtValidator(
            JwtValidators.createDefaultWithIssuer(
                properties.issuer()
                    + REFRESH_ISSUER_SUFFIX
            )
        );

        return decoder;
    }

    private NimbusJwtDecoder createDecoder(
        SecretKey jwtSecretKey
    ) {
        return NimbusJwtDecoder
            .withSecretKey(jwtSecretKey)
            .macAlgorithm(
                MacAlgorithm.HS256
            )
            .build();
    }
}