package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.config.KakaoPaymentProperties;
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
public class KakaoPaymentOrderClient {

  private static final String ORDER_PATH =
      "/online/v1/payment/order";

  private static final String PAYMENT_ACTION_TYPE =
      "PAYMENT";

  private static final String CANCEL_ACTION_TYPE =
      "CANCEL";

  private final KakaoPaymentProperties properties;
  private final RestClient restClient;

  public KakaoPaymentOrderClient(
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
        .defaultHeader(
            HttpHeaders.ACCEPT,
            MediaType.APPLICATION_JSON_VALUE
        )
        .build();
  }

  public LookupResult lookup(
      String tid
  ) {
    if (!properties.hasSecretKey()) {
      return LookupResult.failure(
          "KAKAO_SECRET_KEY_MISSING",
          "카카오페이 Secret key(dev)가 설정되지 않았습니다."
      );
    }

    if (isBlank(tid)) {
      return LookupResult.failure(
          "KAKAO_TID_MISSING",
          "조회할 카카오페이 결제 고유번호가 없습니다."
      );
    }

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
        tid
    );

    try {
      Map<String, Object> response =
          restClient
              .post()
              .uri(ORDER_PATH)
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
        return LookupResult.failure(
            "KAKAO_EMPTY_RESPONSE",
            "카카오페이 주문 조회 응답이 비어 있습니다."
        );
      }

      return parseResponse(response);
    } catch (
        RestClientResponseException exception
    ) {
      KakaoError error =
          extractError(exception);

      return LookupResult.failure(
          error.code(),
          error.message()
      );
    } catch (
        RestClientException exception
    ) {
      return LookupResult.failure(
          "KAKAO_LOOKUP_COMMUNICATION_ERROR",
          "카카오페이 주문 상태를 조회하지 못했습니다."
      );
    }
  }

  private LookupResult parseResponse(
      Map<String, Object> response
  ) {
    String tid = getString(
        response,
        "tid"
    );

    String status = getString(
        response,
        "status"
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

    Long totalAmount = getNestedLong(
        response,
        "amount",
        "total"
    );

    Long canceledAmount = getNestedLong(
        response,
        "canceled_amount",
        "total"
    );

    Long cancelAvailableAmount =
        getNestedLong(
            response,
            "cancel_available_amount",
            "total"
        );

    String createdAt = getString(
        response,
        "created_at"
    );

    String approvedAt = getString(
        response,
        "approved_at"
    );

    String canceledAt = getString(
        response,
        "canceled_at"
    );

    ActionDetail latestPaymentAction =
        findLatestAction(
            response,
            PAYMENT_ACTION_TYPE
        );

    ActionDetail latestCancelAction =
        findLatestAction(
            response,
            CANCEL_ACTION_TYPE
        );

    if (isBlank(tid)
        || isBlank(status)) {
      return LookupResult.failure(
          "KAKAO_INVALID_ORDER_RESPONSE",
          "카카오페이 주문 조회 응답 형식이 올바르지 않습니다."
      );
    }

    return LookupResult.success(
        tid,
        status,
        partnerOrderId,
        partnerUserId,
        paymentMethodType,
        totalAmount,
        canceledAmount,
        cancelAvailableAmount,
        createdAt,
        approvedAt,
        canceledAt,
        latestPaymentAction == null
            ? null
            : latestPaymentAction.aid(),
        latestCancelAction == null
            ? null
            : latestCancelAction.aid(),
        latestCancelAction == null
            ? null
            : latestCancelAction.amount()
    );
  }

  private ActionDetail findLatestAction(
      Map<String, Object> response,
      String expectedActionType
  ) {
    Object value =
        response.get(
            "payment_action_details"
        );

    if (!(value instanceof List<?> actions)
        || actions.isEmpty()) {
      return null;
    }

    for (int index = actions.size() - 1;
         index >= 0;
         index--) {

      Object actionValue =
          actions.get(index);

      if (!(actionValue instanceof Map<?, ?> action)) {
        continue;
      }

      String actionType =
          getStringFromUnknownMap(
              action,
              "payment_action_type"
          );

      if (!expectedActionType.equals(
          actionType
      )) {
        continue;
      }

      String aid =
          getStringFromUnknownMap(
              action,
              "aid"
          );

      Long amount =
          getLongFromUnknownMap(
              action,
              "amount"
          );

      String approvedAt =
          getStringFromUnknownMap(
              action,
              "approved_at"
          );

      return new ActionDetail(
          aid,
          actionType,
          amount,
          approvedAt
      );
    }

    return null;
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
                ? "카카오페이 주문 조회에 실패했습니다."
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
        "카카오페이 주문 조회에 실패했습니다. HTTP 상태: "
            + exception
            .getStatusCode()
            .value()
    );
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

    return getLongFromUnknownMap(
        map,
        childKey
    );
  }

  private String getStringFromUnknownMap(
      Map<?, ?> map,
      String key
  ) {
    Object value = map.get(key);

    return value instanceof String stringValue
        ? stringValue
        : null;
  }

  private Long getLongFromUnknownMap(
      Map<?, ?> map,
      String key
  ) {
    Object value = map.get(key);

    return toLong(value);
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

  public record LookupResult(

      boolean success,

      String tid,

      String status,

      String partnerOrderId,

      String partnerUserId,

      String paymentMethodType,

      Long totalAmount,

      Long canceledAmount,

      Long cancelAvailableAmount,

      String createdAt,

      String approvedAt,

      String canceledAt,

      String latestPaymentAid,

      String latestCancelAid,

      Long latestCancelAmount,

      String failureCode,

      String failureMessage

  ) {

    public static LookupResult success(
        String tid,
        String status,
        String partnerOrderId,
        String partnerUserId,
        String paymentMethodType,
        Long totalAmount,
        Long canceledAmount,
        Long cancelAvailableAmount,
        String createdAt,
        String approvedAt,
        String canceledAt,
        String latestPaymentAid,
        String latestCancelAid,
        Long latestCancelAmount
    ) {
      return new LookupResult(
          true,
          tid,
          status,
          partnerOrderId,
          partnerUserId,
          paymentMethodType,
          totalAmount,
          canceledAmount,
          cancelAvailableAmount,
          createdAt,
          approvedAt,
          canceledAt,
          latestPaymentAid,
          latestCancelAid,
          latestCancelAmount,
          null,
          null
      );
    }

    public static LookupResult failure(
        String failureCode,
        String failureMessage
    ) {
      return new LookupResult(
          false,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          failureCode,
          failureMessage
      );
    }

    public boolean isPaymentCompleted() {
      return "SUCCESS_PAYMENT".equals(status);
    }

    public boolean isPartiallyCanceled() {
      return "PART_CANCEL_PAYMENT".equals(status);
    }

    public boolean isFullyCanceled() {
      return "CANCEL_PAYMENT".equals(status);
    }
  }

  private record ActionDetail(

      String aid,

      String actionType,

      Long amount,

      String approvedAt

  ) {
  }

  private record KakaoError(

      String code,

      String message

  ) {
  }
}