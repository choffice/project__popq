package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.StoreClosureRuleType;
import jakarta.validation.constraints.NotNull;
import java.time.DayOfWeek;

public record StoreClosureRuleRequest(
        @NotNull StoreClosureRuleType ruleType,
        Integer weekOfMonth,
        DayOfWeek dayOfWeek
) {
}
