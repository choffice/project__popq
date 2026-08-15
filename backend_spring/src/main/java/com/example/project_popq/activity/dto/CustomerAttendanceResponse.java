package com.example.project_popq.activity.dto;

import java.time.LocalDate;
import java.util.List;

public record CustomerAttendanceResponse(
        LocalDate today,
        List<LocalDate> checkedDates,
        boolean checkedToday,
        boolean newlyChecked,
        CustomerActivitySummaryResponse activitySummary
) {
}
