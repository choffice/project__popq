package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.config.TossPaymentProperties;
import com.example.project_popq.payment.domain.PaymentProviderType;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

@Component
public class TossPaymentProvider implements PaymentProvider {

  private final TossPaymentProperties properties;
  private final RestClient restClient;

  public TossPaymentProvider(
          TossPaymentProperties properties
  ) {
    this.properties = properties;

    String authorizationValue = createAuthorizationValue(
            properties.secretKey()
    );

    this.restClient = RestClient.builder()
            .baseUrl(removeTrailingSlash(properties.apiBaseUrl()))
            .defaultHeader(
                    HttpHeaders.AUTHORIZATION,
                    authorizationValue
            )
            .defaultHeader(
                    HttpHeaders.CONTENT_TYPE,
                    MediaType.APPLICATION_JSON_VALUE
            )
            .build();
  }

  @Override
  public PaymentProviderType providerType() {
    return PaymentProviderType.TOSS_PAYMENTS;
  }

  @Override
  public PaymentApprovalResult approve(
          PaymentApprovalCommand command
  ) {
    if (isBlank(properties.secretKey())) {
      return PaymentApprovalResult.failure(
              "TOSS_SECRET_KEY_MISSING",
              "토스페이먼츠 시크릿 키가 설정되지 않았습니다."
      );
    }

    if (isBlank(command.paymentKey())) {
      return PaymentApprovalResult.failure(
              "TOSS_PAYMENT_KEY_MISSING",
              "토스페이먼츠 paymentKey가 없습니다."
      );
    }

    Map<String, Object> requestBody = new LinkedHashMap<>();

    requestBody.put(
            "paymentKey",
            command.paymentKey()
    );
    requestBody.put(
            "orderId",
            command.orderPublicId()
    );
    requestBody.put(
            "amount",
            command.amount()
    );

    try {
      Map<String, Object> response = restClient
              .post()
              .uri("/v1/payments/confirm")
              .header(
                      "Idempotency-Key",
                      command.idempotencyKey()
              )
              .body(requestBody)
              .retrieve()
              .body(
                      new ParameterizedTypeReference<>() {
                      }
              );

      if (response == null) {
        return PaymentApprovalResult.failure(
                "TOSS_EMPTY_RESPONSE",
                "토스페이먼츠 승인 응답이 비어 있습니다."
        );
      }

      String providerPaymentKey = getString(
              response,
              "paymentKey"
      );

      Long approvedAmount = getLong(
              response,
              "totalAmount"
      );

      if (isBlank(providerPaymentKey)
              || approvedAmount == null) {
        return PaymentApprovalResult.failure(
                "TOSS_INVALID_RESPONSE",
                "토스페이먼츠 승인 응답 형식이 올바르지 않습니다."
        );
      }

      return PaymentApprovalResult.success(
              providerPaymentKey,
              approvedAmount
      );
    } catch (RestClientResponseException exception) {
      return createApprovalFailure(exception);
    } catch (RestClientException exception) {
      return PaymentApprovalResult.failure(
              "TOSS_COMMUNICATION_ERROR",
              "토스페이먼츠 서버와 통신하지 못했습니다."
      );
    }
  }

  @Override
  public PaymentLookupResult lookup(
          String providerPaymentKey
  ) {
    if (isBlank(properties.secretKey())) {
      return PaymentLookupResult.failure(
              "TOSS_SECRET_KEY_MISSING",
              "토스페이먼츠 시크릿 키가 설정되지 않았습니다."
      );
    }

    if (isBlank(providerPaymentKey)) {
      return PaymentLookupResult.failure(
              "TOSS_PAYMENT_KEY_MISSING",
              "조회할 토스페이먼츠 paymentKey가 없습니다."
      );
    }

    try {
      Map<String, Object> response = restClient
              .get()
              .uri(
                      "/v1/payments/{paymentKey}",
                      providerPaymentKey
              )
              .retrieve()
              .body(
                      new ParameterizedTypeReference<>() {
                      }
              );

      if (response == null) {
        return PaymentLookupResult.failure(
                "TOSS_EMPTY_RESPONSE",
                "토스페이먼츠 결제 조회 응답이 비어 있습니다."
        );
      }

      String responsePaymentKey = getString(
              response,
              "paymentKey"
      );
      String orderPublicId = getString(
              response,
              "orderId"
      );
      Long totalAmount = getLong(
              response,
              "totalAmount"
      );
      String providerStatus = getString(
              response,
              "status"
      );

      if (isBlank(responsePaymentKey)
              || isBlank(orderPublicId)
              || totalAmount == null
              || isBlank(providerStatus)) {
        return PaymentLookupResult.failure(
                "TOSS_INVALID_LOOKUP_RESPONSE",
                "토스페이먼츠 결제 조회 응답 형식이 올바르지 않습니다."
        );
      }

      return PaymentLookupResult.success(
              responsePaymentKey,
              orderPublicId,
              totalAmount,
              mapLookupStatus(providerStatus),
              parseInstant(
                      getString(response, "approvedAt")
              )
      );
    } catch (RestClientResponseException exception) {
      TossError tossError = extractError(exception);

      return PaymentLookupResult.failure(
              tossError.code(),
              tossError.message()
      );
    } catch (RestClientException exception) {
      return PaymentLookupResult.failure(
              "TOSS_COMMUNICATION_ERROR",
              "토스페이먼츠 서버와 통신하지 못했습니다."
      );
    }
  }

  @Override
  public PaymentCancellationResult cancel(
          PaymentCancellationCommand command
  ) {
    if (isBlank(properties.secretKey())) {
      return PaymentCancellationResult.failure(
              "TOSS_SECRET_KEY_MISSING",
              "토스페이먼츠 시크릿 키가 설정되지 않았습니다."
      );
    }

    if (isBlank(command.providerPaymentKey())) {
      return PaymentCancellationResult.failure(
              "TOSS_PAYMENT_KEY_MISSING",
              "취소할 토스페이먼츠 paymentKey가 없습니다."
      );
    }

    Map<String, Object> requestBody = new LinkedHashMap<>();

    requestBody.put(
            "cancelReason",
            command.reason()
    );
    requestBody.put(
            "cancelAmount",
            command.amount()
    );

    try {
      Map<String, Object> response = restClient
              .post()
              .uri(
                      "/v1/payments/{paymentKey}/cancel",
                      command.providerPaymentKey()
              )
              .body(requestBody)
              .retrieve()
              .body(
                      new ParameterizedTypeReference<>() {
                      }
              );

      if (response == null) {
        return PaymentCancellationResult.failure(
                "TOSS_EMPTY_RESPONSE",
                "토스페이먼츠 취소 응답이 비어 있습니다."
        );
      }

      String transactionKey = findLatestCancelTransactionKey(
              response
      );

      if (isBlank(transactionKey)) {
        return PaymentCancellationResult.failure(
                "TOSS_INVALID_CANCEL_RESPONSE",
                "토스페이먼츠 취소 거래 키를 확인할 수 없습니다."
        );
      }

      return PaymentCancellationResult.success(
              transactionKey
      );
    } catch (RestClientResponseException exception) {
      return createCancellationFailure(exception);
    } catch (RestClientException exception) {
      return PaymentCancellationResult.failure(
              "TOSS_COMMUNICATION_ERROR",
              "토스페이먼츠 서버와 통신하지 못했습니다."
      );
    }
  }

  private PaymentApprovalResult createApprovalFailure(
          RestClientResponseException exception
  ) {
    TossError tossError = extractError(exception);

    return PaymentApprovalResult.failure(
            tossError.code(),
            tossError.message()
    );
  }

  private PaymentCancellationResult createCancellationFailure(
          RestClientResponseException exception
  ) {
    TossError tossError = extractError(exception);

    return PaymentCancellationResult.failure(
            tossError.code(),
            tossError.message()
    );
  }

  private TossError extractError(
          RestClientResponseException exception
  ) {
    try {
      Map<String, Object> response =
              exception.getResponseBodyAs(
                      new ParameterizedTypeReference<>() {
                      }
              );

      if (response != null) {
        String code = getString(
                response,
                "code"
        );

        String message = getString(
                response,
                "message"
        );

        return new TossError(
                isBlank(code)
                        ? "TOSS_API_ERROR"
                        : code,
                isBlank(message)
                        ? "토스페이먼츠 요청 처리에 실패했습니다."
                        : message
        );
      }
    } catch (Exception ignored) {
      // 오류 응답 파싱 실패 시 기본 오류를 사용합니다.
    }

    return new TossError(
            "TOSS_API_ERROR",
            "토스페이먼츠 요청 처리에 실패했습니다. HTTP 상태: "
                    + exception.getStatusCode().value()
    );
  }

  private String findLatestCancelTransactionKey(
          Map<String, Object> response
  ) {
    Object cancelsValue = response.get("cancels");

    if (!(cancelsValue instanceof List<?> cancels)
            || cancels.isEmpty()) {
      return null;
    }

    Object latestCancel = cancels.get(
            cancels.size() - 1
    );

    if (!(latestCancel instanceof Map<?, ?> cancelMap)) {
      return null;
    }

    Object transactionKey = cancelMap.get(
            "transactionKey"
    );

    return transactionKey instanceof String value
            ? value
            : null;
  }

  private PaymentLookupResult.Status mapLookupStatus(
          String providerStatus
  ) {
    return switch (providerStatus) {
      case "READY" -> PaymentLookupResult.Status.READY;
      case "IN_PROGRESS", "WAITING_FOR_DEPOSIT" ->
              PaymentLookupResult.Status.IN_PROGRESS;
      case "DONE" -> PaymentLookupResult.Status.PAID;
      case "CANCELED" -> PaymentLookupResult.Status.CANCELED;
      case "PARTIAL_CANCELED" ->
              PaymentLookupResult.Status.PARTIALLY_REFUNDED;
      case "ABORTED" -> PaymentLookupResult.Status.FAILED;
      case "EXPIRED" -> PaymentLookupResult.Status.EXPIRED;
      default -> PaymentLookupResult.Status.UNKNOWN;
    };
  }

  private Instant parseInstant(
          String value
  ) {
    if (isBlank(value)) {
      return null;
    }

    try {
      return OffsetDateTime.parse(value).toInstant();
    } catch (DateTimeParseException ignored) {
      return null;
    }
  }

  private String createAuthorizationValue(
          String secretKey
  ) {
    String safeSecretKey = secretKey == null
            ? ""
            : secretKey;

    String credentials = safeSecretKey + ":";

    String encoded = Base64.getEncoder()
            .encodeToString(
                    credentials.getBytes(
                            StandardCharsets.UTF_8
                    )
            );

    return "Basic " + encoded;
  }

  private String removeTrailingSlash(
          String value
  ) {
    if (value == null || value.isBlank()) {
      return "https://api.tosspayments.com";
    }

    return value.endsWith("/")
            ? value.substring(
            0,
            value.length() - 1
    )
            : value;
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

  private Long getLong(
          Map<String, Object> response,
          String key
  ) {
    Object value = response.get(key);

    return value instanceof Number number
            ? number.longValue()
            : null;
  }

  private boolean isBlank(
          String value
  ) {
    return value == null || value.isBlank();
  }

  private record TossError(
          String code,
          String message
  ) {
  }
}