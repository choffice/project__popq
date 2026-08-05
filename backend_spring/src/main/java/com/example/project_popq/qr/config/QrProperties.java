package com.example.project_popq.qr.config;

import java.net.URI;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.web.util.UriComponentsBuilder;

@ConfigurationProperties(prefix = "popq.qr")
public record QrProperties(
        String publicBaseUrl,
        Duration guestSessionTtl,
        boolean cookieSecure,
        String tokenEncryptionKey
) {

    public QrProperties {
        publicBaseUrl = normalizePublicBaseUrl(publicBaseUrl);
    }

    public String publicOrigin() {
        URI uri = URI.create(publicBaseUrl);
        return UriComponentsBuilder.newInstance()
                .scheme(uri.getScheme())
                .host(uri.getHost())
                .port(uri.getPort())
                .build()
                .toUriString();
    }

    public String publicUrlForToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new IllegalArgumentException("QR token must not be blank");
        }
        return UriComponentsBuilder.fromUriString(publicBaseUrl)
                .pathSegment("q", rawToken)
                .build()
                .encode()
                .toUriString();
    }

    public boolean hasSecurePublicUrl() {
        return "https".equalsIgnoreCase(URI.create(publicBaseUrl).getScheme());
    }

    public boolean hasLoopbackPublicHost() {
        String host = URI.create(publicBaseUrl).getHost().toLowerCase();
        return host.equals("localhost")
                || host.equals("::1")
                || host.startsWith("127.");
    }

    private static String normalizePublicBaseUrl(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(
                    "popq.qr.public-base-url must not be blank"
            );
        }
        String normalized = value.trim().replaceAll("/+$", "");
        URI uri;
        try {
            uri = URI.create(normalized);
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException(
                    "popq.qr.public-base-url must be a valid HTTP(S) URL",
                    exception
            );
        }
        String scheme = uri.getScheme();
        if ((scheme == null
                || !(scheme.equalsIgnoreCase("http")
                || scheme.equalsIgnoreCase("https")))
                || uri.getHost() == null
                || uri.getHost().isBlank()
                || uri.getUserInfo() != null
                || uri.getQuery() != null
                || uri.getFragment() != null) {
            throw new IllegalArgumentException(
                    "popq.qr.public-base-url must be an absolute HTTP(S) URL "
                            + "without credentials, query, or fragment"
            );
        }
        return normalized;
    }
}
