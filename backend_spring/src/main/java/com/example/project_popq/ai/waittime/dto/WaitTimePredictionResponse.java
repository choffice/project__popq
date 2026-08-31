package com.example.project_popq.ai.waittime.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record WaitTimePredictionResponse(

    @JsonProperty("predicted_minutes")
    double predictedMinutes,

    @JsonProperty("recommended_minutes")
    int recommendedMinutes,

    String source,

    @JsonProperty("model_version")
    String modelVersion
) {
}