package com.example.project_popq.store.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.util.List;

public record StoreScheduleRequest(
        @Valid @Size(min = 7, max = 7)
        List<StoreBusinessHourRequest> businessHours,
        @Valid @Size(max = 20)
        List<StoreClosureRuleRequest> closureRules,
        @Valid @Size(max = 50)
        List<StoreScheduleExceptionRequest> scheduleExceptions
) {
}
