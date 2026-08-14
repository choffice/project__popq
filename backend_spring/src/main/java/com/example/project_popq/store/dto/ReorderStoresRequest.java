package com.example.project_popq.store.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.util.List;

public record ReorderStoresRequest(

    @NotEmpty(message = "가게 순서 목록은 비어 있을 수 없습니다.")
    List<
        @NotNull(message = "가게 ID는 null일 수 없습니다.")
        @Positive(message = "가게 ID는 1 이상이어야 합니다.")
            Long
        > storeIds

) {
}