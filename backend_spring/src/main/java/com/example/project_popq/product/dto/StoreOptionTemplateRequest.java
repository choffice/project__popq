package com.example.project_popq.product.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.util.List;

public record StoreOptionTemplateRequest(
        @NotBlank @Size(max = 100) String name,
        @PositiveOrZero int minSelect,
        @PositiveOrZero int maxSelect,
        boolean required,
        @NotNull @Size(min = 1) @Valid List<OptionRequest> options
) {
    public record OptionRequest(
            @NotBlank @Size(max = 100) String name,
            @PositiveOrZero long additionalPrice,
            @PositiveOrZero int displayOrder
    ) {
    }
}
