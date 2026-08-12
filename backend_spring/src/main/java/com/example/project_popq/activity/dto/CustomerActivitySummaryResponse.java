package com.example.project_popq.activity.dto;

import com.example.project_popq.activity.domain.CustomerBadgeTier;
import java.util.List;

public record CustomerActivitySummaryResponse(
        long totalCount,
        CustomerBadgeTier badgeTier,
        int currentCheckpoint,
        Integer nextCheckpoint,
        long remainingCount,
        double checkpointProgress
) {
    private static final List<Integer> CHECKPOINTS = List.of(
            10,
            25,
            50,
            100,
            200,
            300,
            500,
            750,
            1000
    );

    public static CustomerActivitySummaryResponse from(long totalCount) {
        int current = CHECKPOINTS.stream()
                .filter(checkpoint -> checkpoint <= totalCount)
                .reduce((first, second) -> second)
                .orElse(0);
        Integer next = CHECKPOINTS.stream()
                .filter(checkpoint -> checkpoint > totalCount)
                .findFirst()
                .orElse(null);
        long remaining = next == null ? 0 : next - totalCount;
        double progress = next == null
                ? 1.0
                : (double) (totalCount - current) / (next - current);

        return new CustomerActivitySummaryResponse(
                totalCount,
                CustomerBadgeTier.from(totalCount),
                current,
                next,
                remaining,
                progress
        );
    }
}
