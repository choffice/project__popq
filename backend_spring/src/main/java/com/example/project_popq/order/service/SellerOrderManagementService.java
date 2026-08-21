package com.example.project_popq.order.service;

import com.example.project_popq.ai.waittime.dto.WaitTimeRecommendation;
import com.example.project_popq.ai.waittime.service.WaitTimeRecommendationService;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderActorType;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerOrderManagementService {

  private static final Set<Integer> PREPARATION_MINUTES = Set.of(
      0,
      5,
      10,
      15,
      20,
      30,
      40,
      50
  );

  private static final ZoneId BUSINESS_ZONE =
      ZoneId.of("Asia/Seoul");

  private static final Set<OrderStatus> TERMINAL_STATUSES =
      Set.of(
          OrderStatus.COMPLETED,
          OrderStatus.CANCELED,
          OrderStatus.REJECTED,
          OrderStatus.EXPIRED
      );

  private final StoreAuthorizationService storeAuthorizationService;

  private final OrderRepository orderRepository;

  private final OrderDomainEventPublisher orderEventPublisher;

  /*
   * 이번 AI 기능에서 새로 추가된 Service.
   *
   * 실제 주문 데이터를 Feature로 변환하고
   * FastAPI에 요청해서 추천 준비시간을 가져온다.
   */
  private final WaitTimeRecommendationService
      waitTimeRecommendationService;

  @Transactional(readOnly = true)
  public List<OrderResponse> findSellerOrders(
      User user,
      Long storeId,
      OrderStatus status,
      List<OrderStatus> statuses,
      LocalDate date
  ) {
    requireStoreMember(
        user.getId(),
        storeId
    );

    List<Order> orders;

    if (date != null) {
      List<OrderStatus> requestedStatuses =
          status != null
              ? List.of(status)
              : statuses == null
              || statuses.isEmpty()
                ? List.copyOf(
              TERMINAL_STATUSES
          )
                : statuses;

      if (!TERMINAL_STATUSES.containsAll(
          requestedStatuses
      )) {
        throw new BusinessException(
            ErrorCode.INVALID_REQUEST
        );
      }

      Instant fromInclusive =
          date.atStartOfDay(
              BUSINESS_ZONE
          ).toInstant();

      Instant toExclusive =
          date.plusDays(1)
              .atStartOfDay(
                  BUSINESS_ZONE
              )
              .toInstant();

      orders = orderRepository
          .findAllByStoreIdAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(
              storeId,
              requestedStatuses,
              fromInclusive,
              toExclusive
          );

    } else if (status != null) {
      orders = orderRepository
          .findAllByStoreIdAndStatusOrderByCreatedAtDesc(
              storeId,
              status
          );

    } else if (
        statuses != null
            && !statuses.isEmpty()
    ) {
      orders = orderRepository
          .findAllByStoreIdAndStatusInOrderByCreatedAtDesc(
              storeId,
              statuses
          );

    } else {
      orders = orderRepository
          .findAllByStoreIdOrderByCreatedAtDesc(
              storeId
          );
    }

    return orders.stream()
        .map(OrderResponse::from)
        .toList();
  }

  /*
   * ========================================================
   * AI 예상 준비시간 조회
   * ========================================================
   *
   * 판매자가 주문을 접수하기 전에 호출한다.
   *
   * 예:
   *
   * PLACED 주문
   * ↓
   * AI 추천 준비시간 조회
   * ↓
   * "추천 30분"
   * ↓
   * 판매자가 30분 또는 다른 시간을 선택
   * ↓
   * 기존 accept API 호출
   */
  @Transactional(readOnly = true)
  public WaitTimeRecommendation recommendPreparationTime(
      User user,
      Long storeId,
      String orderPublicId
  ) {
    /*
     * 먼저 이 판매자가 해당 매장을
     * 관리할 수 있는 사람인지 확인한다.
     */
    requireStoreMember(
        user.getId(),
        storeId
    );

    /*
     * items까지 같이 불러오는 Repository 메서드를 사용한다.
     *
     * AI Feature 중:
     *
     * - 상품 전체 수량
     * - 메뉴 종류 수
     *
     * 를 계산해야 하기 때문이다.
     */
    Order order = orderRepository
        .findDetailedByOrderPublicIdAndStoreId(
            orderPublicId,
            storeId
        )
        .orElseThrow(
            () -> new BusinessException(
                ErrorCode.ORDER_NOT_FOUND
            )
        );

    /*
     * 현재 단계에서는
     * 판매자가 아직 접수하지 않은 주문에 대해서만
     * AI 추천값을 제공한다.
     *
     * 이미 완료/취소된 주문에서 추천시간을
     * 다시 계산할 이유가 없기 때문이다.
     */
    if (order.getStatus() != OrderStatus.PLACED) {
      throw new BusinessException(
          ErrorCode.INVALID_ORDER_STATUS
      );
    }

    return waitTimeRecommendationService
        .recommend(order);
  }

  @Transactional
  public OrderResponse acceptBySeller(
      User user,
      Long storeId,
      String orderPublicId,
      int preparationMinutes,
      boolean applyAsStoreDefault,
      String reason
  ) {
    requireStoreMember(
        user.getId(),
        storeId
    );

    if (!PREPARATION_MINUTES.contains(
        preparationMinutes
    )) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST
      );
    }

    Order order = lockedSellerOrder(
        storeId,
        orderPublicId
    );

    Instant now = Instant.now();

    OrderTransition transition =
        order.accept(
            preparationMinutes,
            OrderActorType.SELLER,
            user.getId(),
            reason,
            now
        );

    if (applyAsStoreDefault) {
      order.getStore()
          .changeDefaultPreparationMinutes(
              preparationMinutes
          );
    }

    orderRepository.flush();

    orderEventPublisher.publish(
        order,
        transition
    );

    return OrderResponse.from(order);
  }

  private Order lockedSellerOrder(
      Long storeId,
      String orderPublicId
  ) {
    Order order = orderRepository
        .findForUpdateByOrderPublicId(
            orderPublicId
        )
        .orElseThrow(
            () -> new BusinessException(
                ErrorCode.ORDER_NOT_FOUND
            )
        );

    if (!order.getStore()
        .getId()
        .equals(storeId)) {
      throw new BusinessException(
          ErrorCode.ORDER_NOT_FOUND
      );
    }

    return order;
  }

  private void requireStoreMember(
      Long userId,
      Long storeId
  ) {
    storeAuthorizationService.requireAnyRole(
        userId,
        storeId,
        StoreRole.OWNER,
        StoreRole.MANAGER,
        StoreRole.STAFF
    );
  }
}