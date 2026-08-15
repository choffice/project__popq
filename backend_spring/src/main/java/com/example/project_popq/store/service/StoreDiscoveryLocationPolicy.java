package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import java.math.BigDecimal;

public final class StoreDiscoveryLocationPolicy {

    private static final double EARTH_RADIUS_METERS = 6_371_000.0;

    private StoreDiscoveryLocationPolicy() {
    }

    public static void validateOptionalLocation(
            BigDecimal latitude,
            BigDecimal longitude,
            Double radiusKm
    ) {
        if ((latitude == null) != (longitude == null)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
        if (radiusKm != null
                && (latitude == null || radiusKm <= 0 || radiusKm > 100)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
    }

    public static void validateRequiredLocation(
            BigDecimal latitude,
            BigDecimal longitude,
            Double radiusKm
    ) {
        if (latitude == null || longitude == null || radiusKm == null) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
        validateOptionalLocation(latitude, longitude, radiusKm);
    }

    public static double distanceMeters(
            double fromLatitude,
            double fromLongitude,
            double toLatitude,
            double toLongitude
    ) {
        double latitudeDistance = Math.toRadians(toLatitude - fromLatitude);
        double longitudeDistance = Math.toRadians(toLongitude - fromLongitude);
        double startLatitude = Math.toRadians(fromLatitude);
        double endLatitude = Math.toRadians(toLatitude);
        double haversine = Math.pow(Math.sin(latitudeDistance / 2), 2)
                + Math.cos(startLatitude) * Math.cos(endLatitude)
                * Math.pow(Math.sin(longitudeDistance / 2), 2);
        return EARTH_RADIUS_METERS * 2
                * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
    }
}
