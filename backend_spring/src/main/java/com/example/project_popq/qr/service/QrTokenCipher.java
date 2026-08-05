package com.example.project_popq.qr.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.qr.config.QrProperties;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

@Component
public class QrTokenCipher {

    private static final String VERSION = "v1";
    private static final int IV_BYTES = 12;
    private static final int AUTH_TAG_BITS = 128;
    private static final byte[] KEY_CONTEXT =
            "popq:qr-token:v1:".getBytes(StandardCharsets.UTF_8);

    private final SecureRandom secureRandom = new SecureRandom();
    private final SecretKeySpec key;

    public QrTokenCipher(QrProperties properties) {
        String configuredKey = properties.tokenEncryptionKey();
        if (configuredKey == null || configuredKey.length() < 32) {
            throw new IllegalStateException(
                    "POPQ_QR_TOKEN_ENCRYPTION_KEY must contain at least 32 characters"
            );
        }
        this.key = new SecretKeySpec(deriveKey(configuredKey), "AES");
    }

    public String encrypt(String rawToken) {
        try {
            byte[] iv = new byte[IV_BYTES];
            secureRandom.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(
                    Cipher.ENCRYPT_MODE,
                    key,
                    new GCMParameterSpec(AUTH_TAG_BITS, iv)
            );
            byte[] encrypted = cipher.doFinal(
                    rawToken.getBytes(StandardCharsets.UTF_8)
            );
            Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
            return VERSION + "." + encoder.encodeToString(iv)
                    + "." + encoder.encodeToString(encrypted);
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("QR token encryption failed", exception);
        }
    }

    public String decrypt(String ciphertext) {
        try {
            String[] parts = ciphertext.split("\\.", -1);
            if (parts.length != 3 || !VERSION.equals(parts[0])) {
                throw artifactUnavailable();
            }
            Base64.Decoder decoder = Base64.getUrlDecoder();
            byte[] iv = decoder.decode(parts[1]);
            if (iv.length != IV_BYTES) {
                throw artifactUnavailable();
            }
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(
                    Cipher.DECRYPT_MODE,
                    key,
                    new GCMParameterSpec(AUTH_TAG_BITS, iv)
            );
            return new String(
                    cipher.doFinal(decoder.decode(parts[2])),
                    StandardCharsets.UTF_8
            );
        } catch (BusinessException exception) {
            throw exception;
        } catch (GeneralSecurityException | IllegalArgumentException exception) {
            throw artifactUnavailable();
        }
    }

    private byte[] deriveKey(String configuredKey) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(KEY_CONTEXT);
            return digest.digest(configuredKey.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("SHA-256 is not available", exception);
        }
    }

    private BusinessException artifactUnavailable() {
        return new BusinessException(ErrorCode.QR_ARTIFACT_UNAVAILABLE);
    }
}
