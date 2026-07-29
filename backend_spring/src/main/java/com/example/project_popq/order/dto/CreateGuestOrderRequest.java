package com.example.project_popq.order.dto;

import com.example.project_popq.order.domain.OrderType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

public record CreateGuestOrderRequest(
        @NotNull
        @Pattern(regexp = "^[A-Za-z0-9_-]{8,100}$")
        String idempotencyKey,
        @NotNull OrderType orderType,
        @NotNull @Size(min = 1, max = 50) @Valid List<OrderItemRequest> items
) {
    public record OrderItemRequest(
            @NotNull Long productId,
            @Min(1) @Max(99) int quantity,
            @NotNull @Size(max = 100) List<@NotNull Long> optionIds
    ) {
    }
}

