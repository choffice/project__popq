package com.example.project_popq.store.dto;

public record NearbyEventNameSuggestionResponse(
        String eventName,
        long activeStoreCount
) {
}
