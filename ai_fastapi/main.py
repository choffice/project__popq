from pathlib import Path
from typing import Literal

import joblib
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


# ============================================================
# 기본 경로
# ============================================================

BASE_DIR = Path(__file__).resolve().parent

MODEL_PATH = (
    BASE_DIR
    / "models"
    / "wait_time_model.joblib"
)


# ============================================================
# 판매자 주문 접수에서 현재 허용하는 준비시간
#
# Spring Boot의 SellerOrderManagementService에서 허용하는 값과
# 동일하게 유지한다.
# ============================================================

ALLOWED_RECOMMENDATION_MINUTES = (
    5,
    10,
    15,
    20,
    30,
    40,
    50,
)


# ============================================================
# FastAPI
# ============================================================

app = FastAPI(
    title="POPQ AI Wait Time API",
    description=(
        "POPQ 주문 상황을 기반으로 "
        "예상 준비시간을 예측하는 AI API"
    ),
    version="1.0.0",
)


# ============================================================
# 요청 DTO
# ============================================================

class WaitTimePredictionRequest(BaseModel):
    item_count: int = Field(
        ge=1,
        le=100,
        description="주문 전체 상품 수량",
    )

    menu_type_count: int = Field(
        ge=1,
        le=50,
        description="서로 다른 메뉴 종류 수",
    )

    pending_order_count: int = Field(
        ge=0,
        le=200,
        description="현재 대기 주문 수",
    )

    preparing_order_count: int = Field(
        ge=0,
        le=200,
        description="현재 준비 중 주문 수",
    )

    base_preparation_minutes: int = Field(
        ge=5,
        le=120,
        description="매장 기본 준비시간",
    )

    order_hour: int = Field(
        ge=0,
        le=23,
        description="주문 시간",
    )

    day_of_week: int = Field(
        ge=0,
        le=6,
        description="요일: 월요일=0 ~ 일요일=6",
    )

    order_amount: int = Field(
        ge=0,
        description="주문 총 금액",
    )


# ============================================================
# 응답 DTO
# ============================================================

class WaitTimePredictionResponse(BaseModel):
    predicted_minutes: float

    recommended_minutes: int

    source: Literal["AI"]

    model_version: str


class HealthResponse(BaseModel):
    status: str

    model_loaded: bool


# ============================================================
# 모델 캐시
# ============================================================

_model_bundle = None


# ============================================================
# 모델 로딩
# ============================================================

def load_model() -> dict:
    global _model_bundle

    if _model_bundle is not None:
        return _model_bundle

    if not MODEL_PATH.exists():
        raise RuntimeError(
            "학습된 AI 모델이 없습니다. "
            "먼저 'python train_model.py'를 실행하세요."
        )

    _model_bundle = joblib.load(
        MODEL_PATH,
    )

    return _model_bundle


# ============================================================
# 판매자 앱에서 실제 사용할 수 있는 준비시간으로 변환
# ============================================================

def recommend_supported_minutes(
    predicted_minutes: float,
) -> int:
    """
    AI가 예측한 실수 값을 현재 POPQ 주문 접수에서
    실제로 사용할 수 있는 준비시간 중 가장 가까운 값으로 변환한다.

    예:
        22.0분 -> 20분
        26.0분 -> 30분
        34.0분 -> 30분
        37.0분 -> 40분
        55.0분 -> 50분
    """

    return min(
        ALLOWED_RECOMMENDATION_MINUTES,
        key=lambda allowed: abs(
            allowed - predicted_minutes
        ),
    )


# ============================================================
# Health Check
# ============================================================

@app.get(
    "/health",
    response_model=HealthResponse,
)
def health() -> HealthResponse:
    return HealthResponse(
        status="UP",
        model_loaded=MODEL_PATH.exists(),
    )


# ============================================================
# AI 예상 준비시간 API
# ============================================================

@app.post(
    "/api/v1/wait-time/predict",
    response_model=WaitTimePredictionResponse,
)
def predict_wait_time(
    request: WaitTimePredictionRequest,
) -> WaitTimePredictionResponse:

    # 1. 학습 모델 로드
    try:
        bundle = load_model()

    except Exception as error:
        raise HTTPException(
            status_code=503,
            detail=str(error),
        ) from error

    model = bundle["model"]

    # 2. 학습 당시와 동일한 Feature 순서로 구성
    features = np.array(
        [
            [
                request.item_count,
                request.menu_type_count,
                request.pending_order_count,
                request.preparing_order_count,
                request.base_preparation_minutes,
                request.order_hour,
                request.day_of_week,
                request.order_amount,
            ]
        ],
        dtype=float,
    )

    # 3. AI 예측
    predicted_minutes = float(
        model.predict(features)[0]
    )

    # 4. 판매자가 실제 적용 가능한 값으로 변환
    recommended_minutes = (
        recommend_supported_minutes(
            predicted_minutes,
        )
    )

    # 5. 반환
    return WaitTimePredictionResponse(
        predicted_minutes=round(
            predicted_minutes,
            1,
        ),
        recommended_minutes=recommended_minutes,
        source="AI",
        model_version=(
            bundle["model_version"]
        ),
    )