package com.example.project_popq.store.dto;

/**
 * 현재 위치에서 업체까지의 도보 경로 요약입니다.
 *
 * @param distanceMeters 도보 이동 거리, 미터 단위
 * @param durationSeconds 예상 도보 시간, 초 단위
 * @param landingUrl 카카오맵 도보 경로 연결 주소
 */
public record StoreWalkingRouteResponse(
    long distanceMeters,
    long durationSeconds,
    String landingUrl
) {
}