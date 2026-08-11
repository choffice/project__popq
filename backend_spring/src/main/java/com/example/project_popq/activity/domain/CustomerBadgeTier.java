package com.example.project_popq.activity.domain;

public enum CustomerBadgeTier {
    NONE(0),
    BRONZE(10),
    SILVER(100),
    GOLD(500),
    DIAMOND(1000);

    private final long minimumCount;

    CustomerBadgeTier(long minimumCount) {
        this.minimumCount = minimumCount;
    }

    public long minimumCount() {
        return minimumCount;
    }

    public static CustomerBadgeTier from(long activityCount) {
        CustomerBadgeTier result = NONE;
        for (CustomerBadgeTier tier : values()) {
            if (activityCount >= tier.minimumCount) {
                result = tier;
            }
        }
        return result;
    }
}
