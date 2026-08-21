package com.example.project_popq.ai.waittime.service;

import com.example.project_popq.ai.waittime.client.WaitTimeAiClient;
import com.example.project_popq.ai.waittime.dto.WaitTimePredictionRequest;
import com.example.project_popq.ai.waittime.dto.WaitTimePredictionResponse;
import com.example.project_popq.ai.waittime.dto.WaitTimeRecommendation;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.repository.OrderRepository;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class WaitTimeRecommendationService {

  /*
   * Python 모델에서 사용할 시간대.
   *
   * POPQ가 한국 서비스이므로
   * 주문 시각 / 요일은 Asia/Seoul 기준으로 변환한다.
   */
  private static final ZoneId BUSINESS_ZONE =
      ZoneId.of("Asia/Seoul");

  /*
   * 매장에 기본 준비시간이 설정되어 있지 않은 경우
   * 기본적으로 15분을 사용한다.
   */
  private static final int DEFAULT_PREPARATION_MINUTES = 15;

  /*
   * FastAPI Request validation과 동일하게 맞춘다.
   */
  private static final int MIN_PREPARATION_MINUTES = 5;
  private static final int MAX_PREPARATION_MINUTES = 120;

  private static final int MAX_ITEM_COUNT = 100;
  private static final int MAX_MENU_TYPE_COUNT = 50;
  private static final int MAX_ORDER_COUNT = 200;

  private final OrderRepository orderRepository;
  private final WaitTimeAiClient waitTimeAiClient;

  public WaitTimeRecommendation recommend(
      Order order
  ) {
    Objects.requireNonNull(
        order,
        "AI 준비시간 추천 대상 주문은 null일 수 없습니다."
    );

    if (order.getStore() == null
        || order.getStore().getId() == null) {
      throw new IllegalArgumentException(
          "AI 준비시간 추천을 위해 매장 정보가 필요합니다."
      );
    }

    Long storeId = order.getStore().getId();

    /*
     * ----------------------------------------------------
     * Feature 1
     * 전체 상품 수량
     *
     * 예:
     * 아메리카노 2개
     * 샌드위치 3개
     *
     * → itemCount = 5
     * ----------------------------------------------------
     */
    int itemCount = order.getItems()
        .stream()
        .mapToInt(OrderItem::getQuantity)
        .sum();

    itemCount = clamp(
        itemCount,
        1,
        MAX_ITEM_COUNT
    );

    /*
     * ----------------------------------------------------
     * Feature 2
     * 서로 다른 메뉴 종류 수
     *
     * 같은 상품이 옵션만 다르게 여러 줄 존재할 수도 있으므로
     * 상품명 snapshot 기준으로 중복을 제거한다.
     * ----------------------------------------------------
     */
    long distinctMenuCount = order.getItems()
        .stream()
        .map(OrderItem::getProductNameSnapshot)
        .filter(Objects::nonNull)
        .distinct()
        .count();

    int menuTypeCount = clamp(
        Math.toIntExact(distinctMenuCount),
        1,
        MAX_MENU_TYPE_COUNT
    );

    /*
     * ----------------------------------------------------
     * Feature 3
     * 현재 대기 주문 수
     *
     * PLACED =
     * 결제 후 판매자의 처리를 기다리고 있는 주문
     * ----------------------------------------------------
     */
    long pendingCount = orderRepository
        .countByStoreIdAndStatus(
            storeId,
            OrderStatus.PLACED
        );

    int pendingOrderCount = clamp(
        safeLongToInt(pendingCount),
        0,
        MAX_ORDER_COUNT
    );

    /*
     * ----------------------------------------------------
     * Feature 4
     * 현재 준비 중 주문 수
     *
     * 현재 도메인에서는 판매자가 주문을 접수하면
     * 대부분 PREPARING으로 이동한다.
     *
     * 과거/호환성을 위해 ACCEPTED도 같이 센다.
     * ----------------------------------------------------
     */
    long preparingCount = orderRepository
        .countByStoreIdAndStatusIn(
            storeId,
            List.of(
                OrderStatus.ACCEPTED,
                OrderStatus.PREPARING
            )
        );

    int preparingOrderCount = clamp(
        safeLongToInt(preparingCount),
        0,
        MAX_ORDER_COUNT
    );

    /*
     * ----------------------------------------------------
     * Feature 5
     * 매장의 기본 준비시간
     * ----------------------------------------------------
     */
    int basePreparationMinutes =
        normalizeBasePreparationMinutes(
            order.getStore()
                .getDefaultPreparationMinutes()
        );

    /*
     * ----------------------------------------------------
     * Feature 6 / 7
     * 주문 시간 / 요일
     *
     * DB에는 Instant(UTC)로 저장되므로
     * 한국 시간으로 변환한다.
     * ----------------------------------------------------
     */
    Instant orderInstant =
        order.getCreatedAt() != null
            ? order.getCreatedAt()
            : Instant.now();

    ZonedDateTime orderDateTime =
        orderInstant.atZone(
            BUSINESS_ZONE
        );

    int orderHour =
        orderDateTime.getHour();

    /*
     * Java:
     * 월요일 = 1
     * ...
     * 일요일 = 7
     *
     * Python 학습 데이터:
     * 월요일 = 0
     * ...
     * 일요일 = 6
     *
     * 따라서 -1 한다.
     */
    int dayOfWeek =
        orderDateTime
            .getDayOfWeek()
            .getValue()
            - 1;

    /*
     * ----------------------------------------------------
     * Feature 8
     * 주문 총 금액
     * ----------------------------------------------------
     */
    long orderAmount =
        Math.max(
            order.getTotalAmount(),
            0L
        );

    WaitTimePredictionRequest request =
        new WaitTimePredictionRequest(
            itemCount,
            menuTypeCount,
            pendingOrderCount,
            preparingOrderCount,
            basePreparationMinutes,
            orderHour,
            dayOfWeek,
            orderAmount
        );

    try {
      /*
       * 여기에서 실제 FastAPI 서버로 요청이 나간다.
       */
      WaitTimePredictionResponse response =
          waitTimeAiClient.predict(
              request
          );

      int recommendedMinutes =
          normalizeRecommendedMinutes(
              response.recommendedMinutes()
          );

      /*
       * AI 서버의 응답값이 예상 범위를 벗어나더라도
       * Spring에서 한 번 더 안전하게 보정한다.
       */
      WaitTimePredictionResponse normalizedResponse =
          new WaitTimePredictionResponse(
              response.predictedMinutes(),
              recommendedMinutes,
              response.source(),
              response.modelVersion()
          );

      log.info(
          "AI 준비시간 추천 성공. "
              + "orderPublicId={}, "
              + "storeId={}, "
              + "predictedMinutes={}, "
              + "recommendedMinutes={}, "
              + "pendingOrders={}, "
              + "preparingOrders={}",
          order.getOrderPublicId(),
          storeId,
          response.predictedMinutes(),
          recommendedMinutes,
          pendingOrderCount,
          preparingOrderCount
      );

      return WaitTimeRecommendation.fromAi(
          normalizedResponse
      );

    } catch (RuntimeException exception) {

      /*
       * AI 서버가 꺼져 있거나
       * 네트워크 오류가 발생해도
       * 주문 기능 자체가 실패하면 안 된다.
       *
       * 따라서 기존 매장 기본 준비시간을 사용한다.
       */
      log.warn(
          "AI 준비시간 추천 실패. "
              + "기본 준비시간으로 fallback 합니다. "
              + "orderPublicId={}, storeId={}",
          order.getOrderPublicId(),
          storeId,
          exception
      );

      return WaitTimeRecommendation.fallback(
          basePreparationMinutes
      );
    }
  }

  private static int normalizeBasePreparationMinutes(
      Integer minutes
  ) {
    if (minutes == null) {
      return DEFAULT_PREPARATION_MINUTES;
    }

    return clamp(
        minutes,
        MIN_PREPARATION_MINUTES,
        MAX_PREPARATION_MINUTES
    );
  }

  private static int normalizeRecommendedMinutes(
      int minutes
  ) {
    return clamp(
        minutes,
        MIN_PREPARATION_MINUTES,
        MAX_PREPARATION_MINUTES
    );
  }

  private static int safeLongToInt(
      long value
  ) {
    if (value <= 0L) {
      return 0;
    }

    if (value >= Integer.MAX_VALUE) {
      return Integer.MAX_VALUE;
    }

    return (int) value;
  }

  private static int clamp(
      int value,
      int minimum,
      int maximum
  ) {
    return Math.max(
        minimum,
        Math.min(
            value,
            maximum
        )
    );
  }
}