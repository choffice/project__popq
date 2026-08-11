package com.example.project_popq.activity.dto;

public record RecordVisitResponse(
        boolean counted,
        CustomerActivitySummaryResponse activitySummary
) {
}
