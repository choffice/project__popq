package com.example.project_popq.order.service;

import com.example.project_popq.order.dto.CreateCustomerOrderRequest;
import com.example.project_popq.order.dto.CreateGuestOrderRequest;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Comparator;
import java.util.HexFormat;
import org.springframework.stereotype.Component;

@Component
public class OrderRequestHasher {

    public String hash(CreateGuestOrderRequest request) {
        StringBuilder normalized = new StringBuilder(request.orderType().name());

        request.items().stream()
                .map(item -> {
                    String options = item.optionIds().stream()
                            .sorted()
                            .map(String::valueOf)
                            .reduce((left, right) -> left + "," + right)
                            .orElse("");

                    return item.productId()
                            + ":"
                            + item.quantity()
                            + ":"
                            + options;
                })
                .sorted(Comparator.naturalOrder())
                .forEach(item -> normalized.append("|").append(item));

        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(
                            normalized.toString()
                                    .getBytes(StandardCharsets.UTF_8)
                    );

            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    "SHA-256 is not available",
                    exception
            );
        }
    }

    public String hash(CreateCustomerOrderRequest request) {
        StringBuilder normalized =
                new StringBuilder(request.orderType().name());

        request.items().stream()
                .map(item -> normalizeItem(
                        item.productId(),
                        item.quantity(),
                        item.optionIds()
                ))
                .sorted(Comparator.naturalOrder())
                .forEach(item ->
                        normalized.append("|").append(item)
                );

        String requestMessage =
                normalizeRequestMessage(request.requestMessage());

        normalized
                .append("|request:")
                .append(requestMessage.length())
                .append(":")
                .append(requestMessage);

        return sha256(normalized.toString());
    }

    private String normalizeItem(
            Long productId,
            int quantity,
            java.util.List<Long> optionIds
    ) {
        String options = optionIds.stream()
                .sorted()
                .map(String::valueOf)
                .reduce((left, right) -> left + "," + right)
                .orElse("");

        return productId
                + ":"
                + quantity
                + ":"
                + options;
    }

    private String normalizeRequestMessage(String requestMessage) {
        if (requestMessage == null) {
            return "";
        }

        return requestMessage.trim();
    }

    private String sha256(String value) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(
                            value.getBytes(StandardCharsets.UTF_8)
                    );

            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    "SHA-256 is not available",
                    exception
            );
        }
    }
}