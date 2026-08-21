package com.example.project_popq.ai.waittime.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record WaitTimePredictionRequest(

    @JsonProperty("item_count")
    int itemCount,

    @JsonProperty("menu_type_count")
    int menuTypeCount,

    @JsonProperty("pending_order_count")
    int pendingOrderCount,

    @JsonProperty("preparing_order_count")
    int preparingOrderCount,

    @JsonProperty("base_preparation_minutes")
    int basePreparationMinutes,

    @JsonProperty("order_hour")
    int orderHour,

    @JsonProperty("day_of_week")
    int dayOfWeek,

    @JsonProperty("order_amount")
    long orderAmount
) {
}