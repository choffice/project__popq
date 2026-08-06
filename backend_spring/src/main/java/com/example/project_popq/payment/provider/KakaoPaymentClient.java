package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.config.KakaoPaymentProperties;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

@Component
public class KakaoPaymentClient {

    private static final String READY_PATH =
            "/online/v1/payment/ready";

    private final KakaoPaymentProperties properties;
    private final RestClient restClient;

    public KakaoPaymentClient(
            KakaoPaymentProperties properties
    ) {
        this.properties = properties;

        this.restClient = RestClient.builder()
                .baseUrl(
                        properties.resolvedApiBaseUrl()
                )
                .defaultHeader(
                        HttpHeaders.CONTENT_TYPE,
                        MediaType.APPLICATION_JSON_VALUE
                )
                .build();
    }

    public PrepareResult prepare(
            PrepareCommand command
    ) {
        if (!properties.hasSecretKey()) {
            return PrepareResult.failure(
                    "KAKAO_SECRET_KEY_MISSING",
                    "카카오페이 Secret key(dev)가 설정되지 않았습니다."
            );
        }

        validate(command);

        Map<String, Object> requestBody =
                new LinkedHashMap<>();

        requestBody.put(
                "cid",
                properties.resolvedCid()
        );

        if (properties.hasCidSecret()) {
            requestBody.put(
                    "cid_secret",
                    properties.cidSecret()
            );
        }

        requestBody.put(
                "partner_order_id",
                command.partnerOrderId()
        );

        requestBody.put(
                "partner_user_id",
                command.partnerUserId()
        );

        requestBody.put(
                "item_name",
                command.itemName()
        );

        requestBody.put(
                "quantity",
                command.quantity()
        );

        requestBody.put(
                "total_amount",
                command.totalAmount()
        );

        requestBody.put(
                "tax_free_amount",
                command.taxFreeAmount()
        );

        if (command.vatAmount() != null) {
            requestBody.put(
                    "vat_amount",
                    command.vatAmount()
            );
        }

        requestBody.put(
                "approval_url",
                command.approvalUrl()
        );

        requestBody.put(
                "cancel_url",
                command.cancelUrl()
        );

        requestBody.put(
                "fail_url",
                command.failUrl()
        );

        if (!isBlank(command.redirectSchemeUrl())) {
            requestBody.put(
                    "redirect_scheme_url",
                    command.redirectSchemeUrl()
            );
        }

        try {
            Map<String, Object> response =
                    restClient
                            .post()
                            .uri(READY_PATH)
                            .header(
                                    HttpHeaders.AUTHORIZATION,
                                    "SECRET_KEY "
                                            + properties.secretKey()
                            )
                            .body(requestBody)
                            .retrieve()
                            .body(
                                    new ParameterizedTypeReference<>() {
                                    }
                            );

            if (response == null) {
                return PrepareResult.failure(
                        "KAKAO_EMPTY_RESPONSE",
                        "카카오페이 결제 준비 응답이 비어 있습니다."
                );
            }

            String tid = getString(
                    response,
                    "tid"
            );

            String appUrl = getString(
                    response,
                    "next_redirect_app_url"
            );

            String mobileUrl = getString(
                    response,
                    "next_redirect_mobile_url"
            );

            String pcUrl = getString(
                    response,
                    "next_redirect_pc_url"
            );

            String createdAt = getString(
                    response,
                    "created_at"
            );

            if (isBlank(tid)
                    || (
                    isBlank(appUrl)
                            && isBlank(mobileUrl)
            )) {
                return PrepareResult.failure(
                        "KAKAO_INVALID_READY_RESPONSE",
                        "카카오페이 결제 준비 응답 형식이 올바르지 않습니다."
                );
            }

            return PrepareResult.success(
                    tid,
                    appUrl,
                    mobileUrl,
                    pcUrl,
                    createdAt
            );
        } catch (
                RestClientResponseException exception
        ) {
            return extractFailure(exception);
        } catch (
                RestClientException exception
        ) {
            return PrepareResult.failure(
                    "KAKAO_COMMUNICATION_ERROR",
                    "카카오페이 서버와 통신하지 못했습니다."
            );
        }
    }

    private PrepareResult extractFailure(
            RestClientResponseException exception
    ) {
        try {
            Map<String, Object> response =
                    exception.getResponseBodyAs(
                            new ParameterizedTypeReference<>() {
                            }
                    );

            if (response != null) {
                String code = getCode(
                        response.get("error_code")
                );

                String message = getString(
                        response,
                        "error_message"
                );

                return PrepareResult.failure(
                        isBlank(code)
                                ? "KAKAO_API_ERROR"
                                : "KAKAO_" + code,
                        isBlank(message)
                                ? "카카오페이 결제 준비 요청에 실패했습니다."
                                : message
                );
            }
        } catch (Exception ignored) {
            /*
             * 카카오페이 오류 응답 파싱 실패 시
             * 아래의 기본 오류를 사용합니다.
             */
        }

        return PrepareResult.failure(
                "KAKAO_API_ERROR",
                "카카오페이 결제 준비 요청에 실패했습니다. "
                        + "HTTP 상태: "
                        + exception
                        .getStatusCode()
                        .value()
        );
    }

    private void validate(
            PrepareCommand command
    ) {
        requireText(
                command.partnerOrderId(),
                "partnerOrderId"
        );

        requireText(
                command.partnerUserId(),
                "partnerUserId"
        );

        requireText(
                command.itemName(),
                "itemName"
        );

        requireText(
                command.approvalUrl(),
                "approvalUrl"
        );

        requireText(
                command.cancelUrl(),
                "cancelUrl"
        );

        requireText(
                command.failUrl(),
                "failUrl"
        );

        if (command.partnerOrderId().length() > 100) {
            throw new IllegalArgumentException(
                    "partnerOrderId는 100자를 초과할 수 없습니다."
            );
        }

        if (command.partnerUserId().length() > 100) {
            throw new IllegalArgumentException(
                    "partnerUserId는 100자를 초과할 수 없습니다."
            );
        }

        if (command.itemName().length() > 100) {
            throw new IllegalArgumentException(
                    "itemName은 100자를 초과할 수 없습니다."
            );
        }

        if (command.quantity() < 1) {
            throw new IllegalArgumentException(
                    "quantity는 1 이상이어야 합니다."
            );
        }

        if (command.totalAmount() < 1) {
            throw new IllegalArgumentException(
                    "totalAmount는 1원 이상이어야 합니다."
            );
        }

        if (command.taxFreeAmount() < 0
                || command.taxFreeAmount()
                > command.totalAmount()) {
            throw new IllegalArgumentException(
                    "taxFreeAmount가 올바르지 않습니다."
            );
        }

        if (command.vatAmount() != null
                && (
                command.vatAmount() < 0
                        || command.vatAmount()
                        > command.totalAmount()
        )) {
            throw new IllegalArgumentException(
                    "vatAmount가 올바르지 않습니다."
            );
        }
    }

    private void requireText(
            String value,
            String fieldName
    ) {
        if (isBlank(value)) {
            throw new IllegalArgumentException(
                    fieldName + "은(는) 필수입니다."
            );
        }
    }

    private String getString(
            Map<String, Object> response,
            String key
    ) {
        Object value = response.get(key);

        return value instanceof String stringValue
                ? stringValue
                : null;
    }

    private String getCode(
            Object value
    ) {
        if (value instanceof Number number) {
            return String.valueOf(
                    number.longValue()
            );
        }

        return value instanceof String stringValue
                ? stringValue
                : null;
    }

    private boolean isBlank(
            String value
    ) {
        return value == null
                || value.isBlank();
    }

    public record PrepareCommand(
            String partnerOrderId,
            String partnerUserId,
            String itemName,
            int quantity,
            long totalAmount,
            long taxFreeAmount,
            Long vatAmount,
            String approvalUrl,
            String cancelUrl,
            String failUrl,
            String redirectSchemeUrl
    ) {
    }

    public record PrepareResult(
            boolean success,
            String tid,
            String nextRedirectAppUrl,
            String nextRedirectMobileUrl,
            String nextRedirectPcUrl,
            String createdAt,
            String failureCode,
            String failureMessage
    ) {

        public static PrepareResult success(
                String tid,
                String nextRedirectAppUrl,
                String nextRedirectMobileUrl,
                String nextRedirectPcUrl,
                String createdAt
        ) {
            return new PrepareResult(
                    true,
                    tid,
                    nextRedirectAppUrl,
                    nextRedirectMobileUrl,
                    nextRedirectPcUrl,
                    createdAt,
                    null,
                    null
            );
        }

        public static PrepareResult failure(
                String failureCode,
                String failureMessage
        ) {
            return new PrepareResult(
                    false,
                    null,
                    null,
                    null,
                    null,
                    null,
                    failureCode,
                    failureMessage
            );
        }
    }
}