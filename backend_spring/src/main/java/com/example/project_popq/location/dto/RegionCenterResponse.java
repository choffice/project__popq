package com.example.project_popq.location.dto;

/**
 * 사용자가 선택한 탐색 지역의 대표 좌표입니다.
 *
 * <p>소비자 주소/배송지 정보가 아니라 홈과 탐색 화면에서
 * 주변 업체를 조회하기 위한 탐색 기준 위치로만 사용합니다.</p>
 *
 * @param label 표시용 지역명 (예: "서울 성동구", "부산")
 * @param latitude 대표 위도
 * @param longitude 대표 경도
 */
public record RegionCenterResponse(
    String label,
    double latitude,
    double longitude
) {
}