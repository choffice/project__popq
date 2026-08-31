package com.example.project_popq.ai.waittime.client;

import com.example.project_popq.ai.waittime.dto.WaitTimePredictionRequest;
import com.example.project_popq.ai.waittime.dto.WaitTimePredictionResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

@Component
public class WaitTimeAiClient {

  private final RestClient restClient;

  public WaitTimeAiClient(
      @Value(
          "${POPQ_AI_WAIT_TIME_BASE_URL:http://127.0.0.1:8000}"
      )
      String baseUrl
  ) {
    this.restClient = RestClient.builder()
        .baseUrl(normalizeBaseUrl(baseUrl))
        .build();
  }

  public WaitTimePredictionResponse predict(
      WaitTimePredictionRequest request
  ) {
    try {
      WaitTimePredictionResponse response = restClient
          .post()
          .uri("/api/v1/wait-time/predict")
          .contentType(MediaType.APPLICATION_JSON)
          .body(request)
          .retrieve()
          .body(WaitTimePredictionResponse.class);

      if (response == null) {
        throw new IllegalStateException(
            "AI 예상 준비시간 응답이 비어 있습니다."
        );
      }

      return response;

    } catch (RestClientException exception) {
      throw new IllegalStateException(
          "AI 예상 준비시간 서버 호출에 실패했습니다.",
          exception
      );
    }
  }

  private static String normalizeBaseUrl(
      String baseUrl
  ) {
    if (baseUrl == null || baseUrl.isBlank()) {
      return "http://127.0.0.1:8000";
    }

    String normalized = baseUrl.trim();

    while (normalized.endsWith("/")) {
      normalized = normalized.substring(
          0,
          normalized.length() - 1
      );
    }

    return normalized;
  }
}