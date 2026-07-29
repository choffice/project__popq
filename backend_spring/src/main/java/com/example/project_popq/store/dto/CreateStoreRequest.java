package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.StoreType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.Valid;
import java.math.BigDecimal;
import java.util.List;

public record CreateStoreRequest(
        @NotNull StoreType storeType,
        @NotBlank @Size(max = 150) String name,
        @Size(max = 1000) String description,
        @Size(max = 255) String address,
        @DecimalMin("-90.0") @DecimalMax("90.0") BigDecimal latitude,
        @DecimalMin("-180.0") @DecimalMax("180.0") BigDecimal longitude,
        @Valid @Size(max = 10)
        List<@NotBlank @Size(max = 30) String> tags
) {
}
