package com.example.project_popq.ai.waittime.dto;

public record WaitTimeRecommendation(

    int recommendedMinutes,

    Double predictedMinutes,

    String source,

    String modelVersion
) {

  public static WaitTimeRecommendation fromAi(
      WaitTimePredictionResponse response
  ) {
    return new WaitTimeRecommendation(
        response.recommendedMinutes(),
        response.predictedMinutes(),
        "AI",
        response.modelVersion()
    );
  }

  public static WaitTimeRecommendation fallback(
      int fallbackMinutes
  ) {
    return new WaitTimeRecommendation(
        fallbackMinutes,
        null,
        "FALLBACK",
        null
    );
  }

  public boolean aiUsed() {
    return "AI".equals(source);
  }
}