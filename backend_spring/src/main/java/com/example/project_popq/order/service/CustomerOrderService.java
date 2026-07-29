package com.example.project_popq.order.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.config.OrderProperties;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderItemOption;
import com.example.project_popq.order.dto.CreateCustomerOrderRequest;
import com.example.project_popq.order.dto.CreateCustomerOrderRequest.OrderItemRequest;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.dto.OrderSyncResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductOption;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.repository.ProductOptionRepository;
import com.example.project_popq.product.repository.ProductRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
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
public class CustomerOrderService {

    private final StoreRepository storeRepository;
    private final ProductRepository productRepository;
    private final ProductOptionRepository productOptionRepository;
    private final OrderRepository orderRepository;
    private final OrderRequestHasher orderRequestHasher;
    private final OrderProperties properties;

    @Transactional
    public OrderResponse create(
            User user,
            Long storeId,
            CreateCustomerOrderRequest request
    ) {
        requireCustomer(user);
        String requestHash = orderRequestHasher.hash(request);
        Order existing = orderRepository
                .findByIdempotencyKey(request.idempotencyKey())
                .orElse(null);
        if (existing != null) {
            if (!existing.belongsToUser(user.getId())
                    || !existing.getStore().getId().equals(storeId)
                    || !existing.getRequestHash().equals(requestHash)) {
                throw new BusinessException(ErrorCode.IDEMPOTENCY_CONFLICT);
            }
            return OrderResponse.from(existing);
        }

        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        if (!store.isOpen()) {
            throw new BusinessException(ErrorCode.STORE_NOT_OPEN);
        }

        Instant now = Instant.now();
        Order order = Order.createCustomerOrder(
                UUID.randomUUID().toString(),
                user,
                store,
                request.orderType(),
                request.idempotencyKey(),
                requestHash,
                now.plus(properties.paymentDeadline()),
                now
        );
        for (OrderItemRequest itemRequest : request.items()) {
            order.addItem(toOrderItem(order, storeId, itemRequest, now));
        }
        return OrderResponse.from(orderRepository.saveAndFlush(order));
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> findAll(User user) {
        requireCustomer(user);
        return orderRepository.findAllByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(OrderResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public OrderResponse findOne(User user, String orderPublicId) {
        requireCustomer(user);
        return OrderResponse.from(findOwned(user, orderPublicId));
    }

    @Transactional(readOnly = true)
    public OrderSyncResponse sync(
            User user,
            String orderPublicId,
            long knownVersion
    ) {
        requireCustomer(user);
        return OrderSyncResponse.from(findOwned(user, orderPublicId), knownVersion);
    }

    public void requireOwnership(Order order, Long userId) {
        if (!order.belongsToUser(userId)) {
            throw new BusinessException(ErrorCode.ORDER_ACCESS_DENIED);
        }
    }

    private Order findOwned(User user, String orderPublicId) {
        return orderRepository
                .findByOrderPublicIdAndUserId(orderPublicId, user.getId())
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
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
                || !product.getAvailability().isAvailableForCustomerApp(now)) {
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
            if (!option.getOptionGroup().getProduct().getId()
                    .equals(product.getId())
                    || option.getStatus() != CatalogStatus.ACTIVE
                    || option.getOptionGroup().getStatus()
                    != CatalogStatus.ACTIVE) {
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

    private void requireCustomer(User user) {
        if (user.getRole() != PlatformRole.CUSTOMER) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
