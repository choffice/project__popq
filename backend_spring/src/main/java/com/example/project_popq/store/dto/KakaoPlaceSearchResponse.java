package com.example.project_popq.store.dto;

public record KakaoPlaceSearchResponse(
    String placeId,
    String placeName,
    String categoryName,
    String phone,
    String addressName,
    String roadAddressName,
    String placeUrl,
    double latitude,
    double longitude
) {
}