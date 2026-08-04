package com.example.project_popq.store.dto;

public record KakaoReverseGeocodeResponse(
    String addressName,
    String roadAddressName,
    String jibunAddressName,
    String buildingName,
    String zoneNo,
    double latitude,
    double longitude
) {
}