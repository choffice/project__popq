package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.config.KakaoPaymentProperties;
import com.example.project_popq.payment.provider.KakaoPaymentOrderClient.LookupResult;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
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

    private static final String APPROVE_PATH =
            "/online/v1/payment/approve";

    private static final String CANCEL_PATH =
            "/online/v1/payment/cancel";

    private final KakaoPaymentProperties properties;
    private final KakaoPaymentOrderClient kakaoPaymentOrderClient;
    private final RestClient restClient;

    public KakaoPaymentClient(
            KakaoPaymentProperties properties,
            KakaoPaymentOrderClient kakaoPaymentOrderClient
    ) {
        this.properties = properties;
        this.kakaoPaymentOrderClient = kakaoPaymentOrderClient;

        this.restClient = RestClient.builder()
                .baseUrl(
                        properties.resolvedApiBaseUrl()
                )
                .defaultHeader(
                        HttpHeaders.CONTENT_TYPE,
                        MediaType.APPLICATION_JSON_VALUE
                )
                .defaultHeader(
                        HttpHeaders.ACCEPT,
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

        validatePrepareCommand(command);

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
                                    createAuthorizationValue()
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
            KakaoError error = extractError(exception);

            return PrepareResult.failure(
                    error.code(),
                    error.message()
            );
        } catch (
                RestClientException exception
        ) {
            return PrepareResult.failure(
                    "KAKAO_COMMUNICATION_ERROR",
                    "카카오페이 서버와 통신하지 못했습니다."
            );
        }
    }

    public ApproveResult approve(
            ApproveCommand command
    ) {
        if (!properties.hasSecretKey()) {
            return ApproveResult.failure(
                    "KAKAO_SECRET_KEY_MISSING",
                    "카카오페이 Secret key(dev)가 설정되지 않았습니다."
            );
        }

        validateApproveCommand(command);

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
                "tid",
                command.tid()
        );

        requestBody.put(
                "partner_order_id",
                command.partnerOrderId()
        );

        requestBody.put(
                "partner_user_id",
                command.partnerUserId()
        );

        requestBody.put(
                "pg_token",
                command.pgToken()
        );

        try {
            Map<String, Object> response =
                    restClient
                            .post()
                            .uri(APPROVE_PATH)
                            .header(
                                    HttpHeaders.AUTHORIZATION,
                                    createAuthorizationValue()
                            )
                            .body(requestBody)
                            .retrieve()
                            .body(
                                    new ParameterizedTypeReference<>() {
                                    }
                            );

            if (response == null) {
                return recoverApproval(
                        command,
                        ApproveResult.failure(
                                "KAKAO_EMPTY_RESPONSE",
                                "카카오페이 승인 응답이 비어 있습니다."
                        )
                );
            }

            String aid = getString(
                    response,
                    "aid"
            );

            String tid = getString(
                    response,
                    "tid"
            );

            String partnerOrderId = getString(
                    response,
                    "partner_order_id"
            );

            String partnerUserId = getString(
                    response,
                    "partner_user_id"
            );

            String paymentMethodType = getString(
                    response,
                    "payment_method_type"
            );

            Long approvedAmount = getNestedLong(
                    response,
                    "amount",
                    "total"
            );

            String approvedAt = getString(
                    response,
                    "approved_at"
            );

            if (isBlank(aid)
                    || isBlank(tid)
                    || isBlank(partnerOrderId)
                    || isBlank(partnerUserId)
                    || approvedAmount == null
                    || approvedAmount < 1) {
                return recoverApproval(
                        command,
                        ApproveResult.failure(
                                "KAKAO_INVALID_APPROVE_RESPONSE",
                                "카카오페이 승인 응답 형식이 올바르지 않습니다."
                        )
                );
            }

            return ApproveResult.success(
                    aid,
                    tid,
                    partnerOrderId,
                    partnerUserId,
                    paymentMethodType,
                    approvedAmount,
                    approvedAt
            );
        } catch (
                RestClientResponseException exception
        ) {
            KakaoError error = extractError(exception);

            return recoverApproval(
                    command,
                    ApproveResult.failure(
                            error.code(),
                            error.message()
                    )
            );
        } catch (
                RestClientException exception
        ) {
            return recoverApproval(
                    command,
                    ApproveResult.failure(
                            "KAKAO_COMMUNICATION_ERROR",
                            "카카오페이 승인 결과를 확인하지 못했습니다."
                    )
            );
        }
    }

    public CancelResult cancel(
            CancelCommand command
    ) {
        if (!properties.hasSecretKey()) {
            return CancelResult.failure(
                    "KAKAO_SECRET_KEY_MISSING",
                    "카카오페이 Secret key(dev)가 설정되지 않았습니다."
            );
        }

        validateCancelCommand(command);

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
                "tid",
                command.tid()
        );

        requestBody.put(
                "cancel_amount",
                command.cancelAmount()
        );

        requestBody.put(
                "cancel_tax_free_amount",
                command.cancelTaxFreeAmount()
        );

        if (command.cancelVatAmount() != null) {
            requestBody.put(
                    "cancel_vat_amount",
                    command.cancelVatAmount()
            );
        }

        try {
            Map<String, Object> response =
                    restClient
                            .post()
                            .uri(CANCEL_PATH)
                            .header(
                                    HttpHeaders.AUTHORIZATION,
                                    createAuthorizationValue()
                            )
                            .body(requestBody)
                            .retrieve()
                            .body(
                                    new ParameterizedTypeReference<>() {
                                    }
                            );

            if (response == null) {
                return CancelResult.failure(
                        "KAKAO_EMPTY_RESPONSE",
                        "카카오페이 취소 응답이 비어 있습니다."
                );
            }

            String aid = getString(
                    response,
                    "aid"
            );

            String tid = getString(
                    response,
                    "tid"
            );

            String status = getString(
                    response,
                    "status"
            );

            Long approvedCancelAmount = getNestedLong(
                    response,
                    "approved_cancel_amount",
                    "total"
            );

            Long canceledAmount = getNestedLong(
                    response,
                    "canceled_amount",
                    "total"
            );

            Long cancelAvailableAmount = getNestedLong(
                    response,
                    "cancel_available_amount",
                    "total"
            );

            String canceledAt = getString(
                    response,
                    "canceled_at"
            );

            if (isBlank(aid)
                    || isBlank(tid)
                    || isBlank(status)
                    || approvedCancelAmount == null
                    || approvedCancelAmount < 1
                    || canceledAmount == null
                    || cancelAvailableAmount == null) {
                return CancelResult.failure(
                        "KAKAO_INVALID_CANCEL_RESPONSE",
                        "카카오페이 취소 응답 형식이 올바르지 않습니다."
                );
            }

            return CancelResult.success(
                    aid,
                    tid,
                    status,
                    approvedCancelAmount,
                    canceledAmount,
                    cancelAvailableAmount,
                    canceledAt
            );
        } catch (
                RestClientResponseException exception
        ) {
            KakaoError error = extractError(exception);

            return CancelResult.failure(
                    error.code(),
                    error.message()
            );
        } catch (
                RestClientException exception
        ) {
            return CancelResult.failure(
                    "KAKAO_COMMUNICATION_ERROR",
                    "카카오페이 취소 결과를 확인하지 못했습니다."
            );
        }
    }

    private ApproveResult recoverApproval(
            ApproveCommand command,
            ApproveResult originalFailure
    ) {
        LookupResult lookupResult =
                kakaoPaymentOrderClient.lookup(
                        command.tid()
                );

        if (!lookupResult.success()) {
            return originalFailure;
        }

        if (!Objects.equals(
                command.tid(),
                lookupResult.tid()
        )) {
            return ApproveResult.failure(
                    "KAKAO_APPROVE_LOOKUP_TID_MISMATCH",
                    "카카오페이 주문 조회의 결제번호가 준비된 결제와 일치하지 않습니다."
            );
        }

        /*
         * SUCCESS_PAYMENT일 때만 승인 완료로 복구합니다.
         * 부분 취소 또는 전체 취소 상태를 PAID로 되돌리면 안 됩니다.
         */
        if (!lookupResult.isPaymentCompleted()) {
            return originalFailure;
        }

        if (lookupResult.totalAmount() == null
                || lookupResult.totalAmount() < 1) {
            return ApproveResult.failure(
                    "KAKAO_INVALID_APPROVE_LOOKUP_RESPONSE",
                    "카카오페이 주문 조회에서 승인 금액을 확인할 수 없습니다."
            );
        }

        return ApproveResult.success(
                lookupResult.latestPaymentAid(),
                lookupResult.tid(),
                lookupResult.partnerOrderId(),
                lookupResult.partnerUserId(),
                lookupResult.paymentMethodType(),
                lookupResult.totalAmount(),
                lookupResult.approvedAt()
        );
    }

    private KakaoError extractError(
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

                return new KakaoError(
                        isBlank(code)
                                ? "KAKAO_API_ERROR"
                                : "KAKAO_" + code,
                        isBlank(message)
                                ? "카카오페이 요청 처리에 실패했습니다."
                                : message
                );
            }
        } catch (Exception ignored) {
            /*
             * 오류 응답 파싱 실패 시
             * 아래 기본 오류를 사용합니다.
             */
        }

        return new KakaoError(
                "KAKAO_API_ERROR",
                "카카오페이 요청 처리에 실패했습니다. HTTP 상태: "
                        + exception
                        .getStatusCode()
                        .value()
        );
    }

    private void validatePrepareCommand(
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

        validateMaximumLength(
                command.partnerOrderId(),
                "partnerOrderId",
                100
        );

        validateMaximumLength(
                command.partnerUserId(),
                "partnerUserId",
                100
        );

        validateMaximumLength(
                command.itemName(),
                "itemName",
                100
        );

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

    private void validateApproveCommand(
            ApproveCommand command
    ) {
        requireText(
                command.tid(),
                "tid"
        );

        requireText(
                command.partnerOrderId(),
                "partnerOrderId"
        );

        requireText(
                command.partnerUserId(),
                "partnerUserId"
        );

        requireText(
                command.pgToken(),
                "pgToken"
        );

        validateMaximumLength(
                command.partnerOrderId(),
                "partnerOrderId",
                100
        );

        validateMaximumLength(
                command.partnerUserId(),
                "partnerUserId",
                100
        );

        validateMaximumLength(
                command.pgToken(),
                "pgToken",
                255
        );
    }

    private void validateCancelCommand(
            CancelCommand command
    ) {
        requireText(
                command.tid(),
                "tid"
        );

        if (command.cancelAmount() < 1) {
            throw new IllegalArgumentException(
                    "cancelAmount는 1원 이상이어야 합니다."
            );
        }

        if (command.cancelTaxFreeAmount() < 0
                || command.cancelTaxFreeAmount()
                > command.cancelAmount()) {
            throw new IllegalArgumentException(
                    "cancelTaxFreeAmount가 올바르지 않습니다."
            );
        }

        if (command.cancelVatAmount() != null
                && (
                command.cancelVatAmount() < 0
                        || command.cancelVatAmount()
                        > command.cancelAmount()
        )) {
            throw new IllegalArgumentException(
                    "cancelVatAmount가 올바르지 않습니다."
            );
        }
    }

    private void validateMaximumLength(
            String value,
            String fieldName,
            int maximumLength
    ) {
        if (value.length() > maximumLength) {
            throw new IllegalArgumentException(
                    fieldName
                            + "은(는) "
                            + maximumLength
                            + "자를 초과할 수 없습니다."
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

    private String createAuthorizationValue() {
        return "SECRET_KEY "
                + properties.secretKey();
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

    private Long getNestedLong(
            Map<String, Object> response,
            String parentKey,
            String childKey
    ) {
        Object parentValue =
                response.get(parentKey);

        if (!(parentValue instanceof Map<?, ?> map)) {
            return null;
        }

        return toLong(
                map.get(childKey)
        );
    }

    private Long toLong(
            Object value
    ) {
        if (value instanceof Number number) {
            return number.longValue();
        }

        if (value instanceof String stringValue) {
            try {
                return Long.parseLong(
                        stringValue
                );
            } catch (NumberFormatException ignored) {
                return null;
            }
        }

        return null;
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

    public record ApproveCommand(

            String tid,

            String partnerOrderId,

            String partnerUserId,

            String pgToken

    ) {
    }

    public record ApproveResult(

            boolean success,

            String aid,

            String tid,

            String partnerOrderId,

            String partnerUserId,

            String paymentMethodType,

            long approvedAmount,

            String approvedAt,

            String failureCode,

            String failureMessage

    ) {

        public static ApproveResult success(
                String aid,
                String tid,
                String partnerOrderId,
                String partnerUserId,
                String paymentMethodType,
                long approvedAmount,
                String approvedAt
        ) {
            return new ApproveResult(
                    true,
                    aid,
                    tid,
                    partnerOrderId,
                    partnerUserId,
                    paymentMethodType,
                    approvedAmount,
                    approvedAt,
                    null,
                    null
            );
        }

        public static ApproveResult failure(
                String failureCode,
                String failureMessage
        ) {
            return new ApproveResult(
                    false,
                    null,
                    null,
                    null,
                    null,
                    null,
                    0L,
                    null,
                    failureCode,
                    failureMessage
            );
        }
    }

    public record CancelCommand(

            String tid,

            long cancelAmount,

            long cancelTaxFreeAmount,

            Long cancelVatAmount

    ) {
    }

    public record CancelResult(

            boolean success,

            String aid,

            String tid,

            String status,

            long approvedCancelAmount,

            long canceledAmount,

            long cancelAvailableAmount,

            String canceledAt,

            String failureCode,

            String failureMessage

    ) {

        public static CancelResult success(
                String aid,
                String tid,
                String status,
                long approvedCancelAmount,
                long canceledAmount,
                long cancelAvailableAmount,
                String canceledAt
        ) {
            return new CancelResult(
                    true,
                    aid,
                    tid,
                    status,
                    approvedCancelAmount,
                    canceledAmount,
                    cancelAvailableAmount,
                    canceledAt,
                    null,
                    null
            );
        }

        public static CancelResult failure(
                String failureCode,
                String failureMessage
        ) {
            return new CancelResult(
                    false,
                    null,
                    null,
                    null,
                    0L,
                    0L,
                    0L,
                    null,
                    failureCode,
                    failureMessage
            );
        }
    }

    private record KakaoError(

            String code,

            String message

    ) {
    }
}
