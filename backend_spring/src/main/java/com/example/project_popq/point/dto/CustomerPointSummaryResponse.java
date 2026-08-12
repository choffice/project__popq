package com.example.project_popq.point.dto;

import java.util.List;

public record CustomerPointSummaryResponse(
        long balance,
        double rewardRatePercent,
        List<CustomerPointHistoryResponse> histories
) {
}
