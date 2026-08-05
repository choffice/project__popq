package com.example.project_popq.location.dto;

/**
 * 좌표를 역지오코딩해 얻은 표시용 위치 라벨입니다.
 *
 * @param label "부산 해운대구"처럼 시/도(축약형)와 구/군을 합친 라벨
 */
public record ReverseGeocodeResponse(
        String label
) {
}
