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

  private static final Set<Integer> PREPARATION_MINUTES =
          Set.of(
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
          ZoneId.of(
                  "Asia/Seoul"
          );

  private static final Set<OrderStatus> TERMINAL_STATUSES =
          Set.of(
                  OrderStatus.COMPLETED,
                  OrderStatus.CANCELED,
                  OrderStatus.REJECTED,
                  OrderStatus.EXPIRED
          );

  private final StoreAuthorizationService
          storeAuthorizationService;

  private final OrderRepository
          orderRepository;

  private final OrderDomainEventPublisher
          orderEventPublisher;

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
                      ? List.of(
                      status
              )
                      : statuses == null ||
                      statuses.isEmpty()
                      ? List.copyOf(
                      TERMINAL_STATUSES
              )
                      : statuses;

      if (
              !TERMINAL_STATUSES
                      .containsAll(
                              requestedStatuses
                      )
      ) {
        throw new BusinessException(
                ErrorCode.INVALID_REQUEST
        );
      }

      Instant fromInclusive =
              date.atStartOfDay(
                              BUSINESS_ZONE
                      )
                      .toInstant();

      Instant toExclusive =
              date.plusDays(1)
                      .atStartOfDay(
                              BUSINESS_ZONE
                      )
                      .toInstant();

      orders =
              orderRepository
                      .findAllByStoreIdAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(
                              storeId,
                              requestedStatuses,
                              fromInclusive,
                              toExclusive
                      );

    } else if (status != null) {
      orders =
              orderRepository
                      .findAllByStoreIdAndStatusOrderByCreatedAtDesc(
                              storeId,
                              status
                      );

    } else if (
            statuses != null &&
                    !statuses.isEmpty()
    ) {
      orders =
              orderRepository
                      .findAllByStoreIdAndStatusInOrderByCreatedAtDesc(
                              storeId,
                              statuses
                      );

    } else {
      orders =
              orderRepository
                      .findAllByStoreIdOrderByCreatedAtDesc(
                              storeId
                      );
    }

    return orders.stream()
            .map(
                    OrderResponse::from
            )
            .toList();
  }

  @Transactional(readOnly = true)
  public WaitTimeRecommendation recommendPreparationTime(
          User user,
          Long storeId,
          String orderPublicId
  ) {
    requireStoreMember(
            user.getId(),
            storeId
    );

    Order order =
            orderRepository
                    .findDetailedByOrderPublicIdAndStoreId(
                            orderPublicId,
                            storeId
                    )
                    .orElseThrow(
                            () ->
                                    new BusinessException(
                                            ErrorCode.ORDER_NOT_FOUND
                                    )
                    );

    if (
            order.getStatus() !=
                    OrderStatus.PLACED
    ) {
      throw new BusinessException(
              ErrorCode.INVALID_ORDER_STATUS
      );
    }

    return waitTimeRecommendationService
            .recommend(
                    order
            );
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

    validatePreparationMinutes(
            preparationMinutes
    );

    Order order =
            lockedSellerOrder(
                    storeId,
                    orderPublicId
            );

    Instant now =
            Instant.now();

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

    return OrderResponse.from(
            order
    );
  }

  /*
   * ========================================================
   * 접수 후 준비시간 수정
   * ========================================================
   *
   * 판매자가 주문을 접수한 뒤
   * 상황에 따라 예상 준비시간을 다시 바꿀 수 있다.
   *
   * 변경 가능한 상태:
   *
   * ACCEPTED
   * PREPARING
   *
   * READY 이후에는 이미 준비가 끝난 상태이므로
   * 변경할 수 없다.
   */
  @Transactional
  public OrderResponse updatePreparationTimeBySeller(
          User user,
          Long storeId,
          String orderPublicId,
          int preparationMinutes,
          boolean applyAsStoreDefault
  ) {
    requireStoreMember(
            user.getId(),
            storeId
    );

    validatePreparationMinutes(
            preparationMinutes
    );

    Order order =
            lockedSellerOrder(
                    storeId,
                    orderPublicId
            );

    /*
     * updatePreparationTime 내부에서도
     * ACCEPTED / PREPARING 상태 여부를 검증한다.
     */
    OrderStatus currentStatus =
            order.getStatus();

    Instant now =
            Instant.now();

    order.updatePreparationTime(
            preparationMinutes
    );

    if (applyAsStoreDefault) {
      order.getStore()
              .changeDefaultPreparationMinutes(
                      preparationMinutes
              );
    }

    /*
     * JPA @Version 값을 실제로 증가시키기 위해
     * 실시간 이벤트 생성 전에 flush 한다.
     */
    orderRepository.flush();

    /*
     * 주문 상태 자체는 변하지 않았지만
     * preparationMinutes / estimatedReadyAt가 변경됐다.
     *
     * 기존 주문 실시간 구조를 그대로 활용하기 위해
     * 현재 상태 → 현재 상태 형태의 이벤트를 발행한다.
     *
     * 예:
     *
     * PREPARING → PREPARING
     *
     * 하지만 version 값은 증가하기 때문에
     * 판매자/구매자 앱에서 새 이벤트로 인식한다.
     *
     * 앱은 이벤트를 받은 뒤 REST sync를 수행해서
     * 변경된 preparationMinutes,
     * estimatedReadyAt 값을 가져오게 된다.
     */
    orderEventPublisher.publish(
            order,
            new OrderTransition(
                    currentStatus,
                    currentStatus,
                    now
            )
    );

    return OrderResponse.from(
            order
    );
  }

  private void validatePreparationMinutes(
          int preparationMinutes
  ) {
    if (
            !PREPARATION_MINUTES.contains(
                    preparationMinutes
            )
    ) {
      throw new BusinessException(
              ErrorCode.INVALID_REQUEST
      );
    }
  }

  private Order lockedSellerOrder(
          Long storeId,
          String orderPublicId
  ) {
    Order order =
            orderRepository
                    .findForUpdateByOrderPublicId(
                            orderPublicId
                    )
                    .orElseThrow(
                            () ->
                                    new BusinessException(
                                            ErrorCode.ORDER_NOT_FOUND
                                    )
                    );

    if (
            !order.getStore()
                    .getId()
                    .equals(
                            storeId
                    )
    ) {
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
    storeAuthorizationService
            .requireAnyRole(
                    userId,
                    storeId,
                    StoreRole.OWNER,
                    StoreRole.MANAGER,
                    StoreRole.STAFF
            );
  }
}