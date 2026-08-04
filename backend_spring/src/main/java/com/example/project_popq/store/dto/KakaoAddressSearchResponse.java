package com.example.project_popq.store.dto;

public record KakaoAddressSearchResponse(
    String addressName,
    String roadAddressName,
    String jibunAddressName,
    String zoneNo,
    double latitude,
    double longitude
) {
}