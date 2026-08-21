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

    # 이미 한 번 불러왔다면
    # 매 요청마다 다시 파일을 읽지 않는다.
    if _model_bundle is not None:
        return _model_bundle

    # 모델 파일 존재 여부 확인
    if not MODEL_PATH.exists():
        raise RuntimeError(
            "학습된 AI 모델이 없습니다. "
            "먼저 'python train_model.py'를 실행하세요."
        )

    # joblib 파일에서 학습된 모델 불러오기
    _model_bundle = joblib.load(
        MODEL_PATH,
    )

    return _model_bundle


# ============================================================
# 5분 단위 추천시간 변환
# ============================================================

def round_to_five_minutes(
    minutes: float,
) -> int:
    """
    AI가 예측한 시간을 판매자가 사용하기 편하도록
    가장 가까운 5분 단위로 변환한다.

    예:
        22.8분 -> 25분
        26.1분 -> 25분
        28.7분 -> 30분
    """

    rounded = int(
        round(minutes / 5.0) * 5
    )

    # 최소 5분 / 최대 120분
    return max(
        5,
        min(
            rounded,
            120,
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

    # --------------------------------------------------------
    # 1. 학습 모델 불러오기
    # --------------------------------------------------------

    try:
        bundle = load_model()

    except Exception as error:
        raise HTTPException(
            status_code=503,
            detail=str(error),
        ) from error

    model = bundle["model"]

    # --------------------------------------------------------
    # 2. API 요청값을
    #    AI가 학습했던 Feature 순서로 구성
    #
    # 반드시 train_model.py의 FEATURE_NAMES 순서와
    # 동일해야 한다.
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # 3. AI 예측
    # --------------------------------------------------------

    predicted_minutes = float(
        model.predict(features)[0]
    )

    # --------------------------------------------------------
    # 4. 판매자가 사용하기 편하도록
    #    5분 단위 추천값 생성
    # --------------------------------------------------------

    recommended_minutes = (
        round_to_five_minutes(
            predicted_minutes,
        )
    )

    # --------------------------------------------------------
    # 5. 결과 반환
    # --------------------------------------------------------

    return WaitTimePredictionResponse(
        predicted_minutes=round(
            predicted_minutes,
            1,
        ),
        recommended_minutes=(
            recommended_minutes
        ),
        source="AI",
        model_version=(
            bundle["model_version"]
        ),
    )