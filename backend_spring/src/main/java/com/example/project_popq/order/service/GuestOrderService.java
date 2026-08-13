package com.example.project_popq.order.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.config.OrderProperties;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderItemOption;
import com.example.project_popq.order.dto.CreateGuestOrderRequest;
import com.example.project_popq.order.dto.CreateGuestOrderRequest.OrderItemRequest;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.dto.OrderSyncResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductOption;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.repository.ProductOptionRepository;
import com.example.project_popq.product.repository.ProductRepository;
import com.example.project_popq.qr.domain.GuestSession;
import com.example.project_popq.qr.repository.GuestSessionRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.store.domain.Store;
import java.time.Instant;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class GuestOrderService {

    private final GuestQrService guestQrService;
    private final GuestSessionRepository guestSessionRepository;
    private final ProductRepository productRepository;
    private final ProductOptionRepository productOptionRepository;
    private final OrderRepository orderRepository;
    private final OrderRequestHasher orderRequestHasher;
    private final OrderProperties properties;

    @Transactional
    public OrderResponse create(
            String rawSessionToken,
            CreateGuestOrderRequest request
    ) {
        ResolvedGuestSession resolved = guestQrService.resolve(rawSessionToken);
        String requestHash = orderRequestHasher.hash(request);

        Order existing = orderRepository
                .findByIdempotencyKey(request.idempotencyKey())
                .orElse(null);
        if (existing != null) {
            validateIdempotentReplay(existing, resolved, requestHash);
            return OrderResponse.from(existing);
        }

        GuestSession guestSession = guestSessionRepository
                .findById(resolved.guestSessionId())
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.GUEST_SESSION_INVALID
                ));
        Instant now = Instant.now();
        Store store = guestSession.getQrCode().getStore();
        if (!store.isOrderAccepting()) {
            throw new BusinessException(ErrorCode.STORE_NOT_OPEN);
        }
        Order order = Order.createGuestOrder(
                UUID.randomUUID().toString(),
                guestSession,
                store,
                request.orderType(),
                request.idempotencyKey(),
                requestHash,
                now.plus(properties.paymentDeadline()),
                now
        );

        for (OrderItemRequest itemRequest : request.items()) {
            order.addItem(toOrderItem(order, resolved.storeId(), itemRequest, now));
        }

        return OrderResponse.from(orderRepository.saveAndFlush(order));
    }

    @Transactional(readOnly = true)
    public OrderResponse get(
            String rawSessionToken,
            String orderPublicId
    ) {
        ResolvedGuestSession resolved = guestQrService.resolve(rawSessionToken);
        Order order = orderRepository.findByOrderPublicId(orderPublicId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
        requireGuestOwnership(order, resolved.guestSessionId());
        return OrderResponse.from(order);
    }

    @Transactional(readOnly = true)
    public OrderSyncResponse sync(
            String rawSessionToken,
            String orderPublicId,
            long knownVersion
    ) {
        ResolvedGuestSession resolved = guestQrService.resolve(rawSessionToken);
        Order order = orderRepository.findByOrderPublicId(orderPublicId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
        requireGuestOwnership(order, resolved.guestSessionId());
        return OrderSyncResponse.from(order, knownVersion);
    }

    public void requireGuestOwnership(Order order, Long guestSessionId) {
        if (!order.belongsToGuestSession(guestSessionId)) {
            throw new BusinessException(ErrorCode.ORDER_ACCESS_DENIED);
        }
    }

    private OrderItem toOrderItem(
            Order order,
            Long storeId,
            OrderItemRequest request,
            Instant now
    ) {
        Product product = productRepository
                .findDetailedByIdAndStoreId(request.productId(), storeId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.PRODUCT_NOT_FOUND
                ));
        if (product.getStatus() != CatalogStatus.ACTIVE
                || !product.getAvailability().isAvailableForQr(now)) {
            throw new BusinessException(ErrorCode.PRODUCT_UNAVAILABLE);
        }

        Set<Long> selectedIds = new HashSet<>(request.optionIds());
        if (selectedIds.size() != request.optionIds().size()) {
            throw new BusinessException(ErrorCode.INVALID_OPTION_SELECTION);
        }
        List<ProductOption> selectedOptions = productOptionRepository
                .findAllById(selectedIds);
        validateSelectedOptions(product, selectedOptions, selectedIds);

        OrderItem item = OrderItem.create(order, product, request.quantity());
        for (ProductOption option : selectedOptions) {
            item.addOption(OrderItemOption.create(item, option));
        }
        try {
            item.calculateTotal();
        } catch (ArithmeticException exception) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "주문 금액이 허용 범위를 초과했습니다."
            );
        }
        return item;
    }

    private void validateSelectedOptions(
            Product product,
            List<ProductOption> selectedOptions,
            Set<Long> selectedIds
    ) {
        if (selectedOptions.size() != selectedIds.size()) {
            throw new BusinessException(ErrorCode.OPTION_NOT_FOUND);
        }
        for (ProductOption option : selectedOptions) {
            if (!option.getOptionGroup().getProduct().getId().equals(product.getId())
                    || option.getStatus() != CatalogStatus.ACTIVE
                    || option.getOptionGroup().getStatus() != CatalogStatus.ACTIVE) {
                throw new BusinessException(ErrorCode.OPTION_NOT_FOUND);
            }
        }

        Map<Long, Integer> selectedCountByGroup = new HashMap<>();
        for (ProductOption option : selectedOptions) {
            selectedCountByGroup.merge(
                    option.getOptionGroup().getId(),
                    1,
                    Integer::sum
            );
        }
        for (ProductOptionGroup group : product.getOptionGroups()) {
            if (group.getStatus() != CatalogStatus.ACTIVE) {
                continue;
            }
            int count = selectedCountByGroup.getOrDefault(group.getId(), 0);
            if (count < group.getMinSelect() || count > group.getMaxSelect()) {
                throw new BusinessException(ErrorCode.INVALID_OPTION_SELECTION);
            }
        }
    }

    private void validateIdempotentReplay(
            Order existing,
            ResolvedGuestSession resolved,
            String requestHash
    ) {
        if (!existing.belongsToGuestSession(resolved.guestSessionId())
                || !existing.getRequestHash().equals(requestHash)) {
            throw new BusinessException(ErrorCode.IDEMPOTENCY_CONFLICT);
        }
    }
}
