from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split


# ============================================================
# 기본 설정
# ============================================================

BASE_DIR = Path(__file__).resolve().parent

MODEL_DIR = BASE_DIR / "models"

MODEL_PATH = MODEL_DIR / "wait_time_model.joblib"

RANDOM_SEED = 42

SAMPLE_COUNT = 5000


# AI가 학습할 입력값 이름
FEATURE_NAMES = [
    "item_count",
    "menu_type_count",
    "pending_order_count",
    "preparing_order_count",
    "base_preparation_minutes",
    "order_hour",
    "day_of_week",
    "order_amount",
]


# ============================================================
# 시뮬레이션 학습 데이터 생성
# ============================================================


def create_simulation_data(
    sample_count: int,
) -> tuple[np.ndarray, np.ndarray]:
    """
    실제 POPQ 주문 데이터가 충분히 쌓이기 전까지
    AI 학습/추론 구조를 검증하기 위한
    시뮬레이션 주문 데이터를 생성한다.

    X:
        AI에게 보여주는 주문 상황

    y:
        실제 준비시간이라고 가정한 정답
    """

    rng = np.random.default_rng(
        RANDOM_SEED,
    )

    # --------------------------------------------------------
    # 1. 주문 상품 전체 수량
    #
    # 예:
    # 아메리카노 2개
    # 샌드위치 1개
    #
    # → item_count = 3
    # --------------------------------------------------------

    item_count = rng.integers(
        low=1,
        high=16,
        size=sample_count,
    )

    # --------------------------------------------------------
    # 2. 서로 다른 메뉴 종류 수
    #
    # 상품이 5개라고 해도
    # 같은 상품 5개일 수도 있고
    # 서로 다른 상품 5개일 수도 있다.
    # --------------------------------------------------------

    menu_type_count = np.array(
        [
            rng.integers(
                low=1,
                high=min(
                    int(item_count_value),
                    6,
                )
                + 1,
            )
            for item_count_value in item_count
        ],
        dtype=int,
    )

    # --------------------------------------------------------
    # 3. 현재 대기 주문 수
    # --------------------------------------------------------

    pending_order_count = rng.integers(
        low=0,
        high=16,
        size=sample_count,
    )

    # --------------------------------------------------------
    # 4. 현재 준비 중 주문 수
    # --------------------------------------------------------

    preparing_order_count = rng.integers(
        low=0,
        high=11,
        size=sample_count,
    )

    # --------------------------------------------------------
    # 5. 매장이 설정한 기본 준비시간
    #
    # 중요:
    # 특정 값 중 하나를 고를 때는
    # rng.integers()가 아니라 rng.choice()를 사용한다.
    # --------------------------------------------------------

    base_preparation_minutes = rng.choice(
        [
            10,
            15,
            20,
            25,
            30,
        ],
        size=sample_count,
    )

    # --------------------------------------------------------
    # 6. 주문 시간
    #
    # 0 ~ 23
    # --------------------------------------------------------

    order_hour = rng.integers(
        low=0,
        high=24,
        size=sample_count,
    )

    # --------------------------------------------------------
    # 7. 요일
    #
    # 0 = 월요일
    # 1 = 화요일
    # 2 = 수요일
    # 3 = 목요일
    # 4 = 금요일
    # 5 = 토요일
    # 6 = 일요일
    # --------------------------------------------------------

    day_of_week = rng.integers(
        low=0,
        high=7,
        size=sample_count,
    )

    # --------------------------------------------------------
    # 8. 주문 금액
    # --------------------------------------------------------

    order_amount = rng.integers(
        low=5000,
        high=120001,
        size=sample_count,
    )

    # ========================================================
    # 피크 시간 Feature 계산
    # ========================================================

    # 점심시간
    lunch_peak = (
        (order_hour >= 11)
        & (order_hour <= 13)
    ).astype(int)

    # 저녁시간
    dinner_peak = (
        (order_hour >= 17)
        & (order_hour <= 20)
    ).astype(int)

    # 토요일 / 일요일
    weekend = (
        day_of_week >= 5
    ).astype(int)

    # ========================================================
    # 가상의 실제 준비시간 생성
    # ========================================================
    #
    # 현재는 실제 서비스 주문 데이터가 충분하지 않다.
    #
    # 그래서 아래 규칙을 이용해서
    # "실제로 걸린 준비시간"이라고 가정할 값을 만든다.
    #
    # 나중에는 이 부분을 제거하고:
    #
    # READY 시각 - ACCEPTED 시각
    #
    # 으로 실제 정답 데이터를 생성하게 된다.
    # ========================================================

    actual_preparation_minutes = (
        base_preparation_minutes

        # 상품이 많을수록 시간 증가
        + item_count * 0.8

        # 메뉴 종류가 많을수록 시간 증가
        + menu_type_count * 0.6

        # 대기 주문이 많을수록 시간 증가
        + pending_order_count * 0.7

        # 현재 준비 중인 주문이 많을수록 시간 증가
        + preparing_order_count * 1.1

        # 점심 피크
        + lunch_peak * 3.0

        # 저녁 피크
        + dinner_peak * 4.0

        # 주말
        + weekend * 1.5

        # 주문금액도 아주 약하게 반영
        + (order_amount / 10000.0) * 0.15
    )

    # --------------------------------------------------------
    # 현실에서는 같은 조건의 주문이라도
    # 항상 정확히 같은 시간이 걸리지는 않는다.
    #
    # 그래서 ±몇 분 정도의 랜덤 오차를 넣는다.
    # --------------------------------------------------------

    noise = rng.normal(
        loc=0.0,
        scale=3.0,
        size=sample_count,
    )

    actual_preparation_minutes = (
        actual_preparation_minutes
        + noise
    )

    # --------------------------------------------------------
    # 비현실적인 값 방지
    #
    # 최소 5분
    # 최대 90분
    # --------------------------------------------------------

    actual_preparation_minutes = np.clip(
        actual_preparation_minutes,
        5,
        90,
    )

    # ========================================================
    # X 데이터 생성
    # ========================================================
    #
    # 한 줄이 주문 한 건이다.
    #
    # 예:
    #
    # [
    #   5,      상품 개수
    #   3,      메뉴 종류
    #   7,      대기 주문
    #   4,      준비 주문
    #   15,     기본 준비시간
    #   18,     오후 6시
    #   4,      금요일
    #   42000   주문금액
    # ]
    # ========================================================

    X = np.column_stack(
        [
            item_count,
            menu_type_count,
            pending_order_count,
            preparing_order_count,
            base_preparation_minutes,
            order_hour,
            day_of_week,
            order_amount,
        ]
    ).astype(float)

    # ========================================================
    # y 데이터
    # ========================================================
    #
    # AI가 맞혀야 하는 정답
    #
    # = 실제 준비시간
    # ========================================================

    y = actual_preparation_minutes.astype(
        float,
    )

    return X, y


# ============================================================
# AI 모델 학습
# ============================================================


def train_model() -> None:
    print("=" * 60)

    print(
        "POPQ AI 예상 준비시간 모델 학습 시작"
    )

    print("=" * 60)

    # --------------------------------------------------------
    # 1. 데이터 생성
    # --------------------------------------------------------

    X, y = create_simulation_data(
        SAMPLE_COUNT,
    )

    print(
        f"전체 데이터 수: {len(X):,}건"
    )

    print(
        f"Feature 수: {len(FEATURE_NAMES)}개"
    )

    # --------------------------------------------------------
    # 2. 학습 데이터 / 검증 데이터 분리
    #
    # 80% = AI가 공부하는 데이터
    # 20% = 공부한 AI를 시험하는 데이터
    # --------------------------------------------------------

    X_train, X_test, y_train, y_test = (
        train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=RANDOM_SEED,
        )
    )

    print(
        f"학습 데이터: {len(X_train):,}건"
    )

    print(
        f"검증 데이터: {len(X_test):,}건"
    )

    # --------------------------------------------------------
    # 3. Random Forest 회귀 모델 생성
    #
    # Regressor = 숫자를 예측하는 모델
    #
    # 우리는 "몇 분"이라는 숫자를 예측하므로
    # 분류(Classification)가 아니라
    # 회귀(Regression)를 사용한다.
    # --------------------------------------------------------

    model = RandomForestRegressor(
        n_estimators=200,
        max_depth=14,
        min_samples_leaf=2,
        random_state=RANDOM_SEED,
        n_jobs=-1,
    )

    # --------------------------------------------------------
    # 4. AI 학습
    #
    # X_train:
    #   주문 상황
    #
    # y_train:
    #   그 주문의 실제 준비시간
    #
    # 이 둘의 관계를 모델이 학습한다.
    # --------------------------------------------------------

    model.fit(
        X_train,
        y_train,
    )

    # --------------------------------------------------------
    # 5. 학습에 사용하지 않은 검증 데이터로 예측
    # --------------------------------------------------------

    predictions = model.predict(
        X_test,
    )

    # --------------------------------------------------------
    # 6. MAE 계산
    #
    # Mean Absolute Error
    #
    # 실제 시간과 예측 시간의 차이가
    # 평균 몇 분인지 보여준다.
    #
    # 예:
    #
    # MAE = 2.5
    #
    # → 평균적으로 약 2.5분 정도 오차
    # --------------------------------------------------------

    mae = mean_absolute_error(
        y_test,
        predictions,
    )

    # --------------------------------------------------------
    # 7. R² 계산
    #
    # 모델이 데이터 변화를 얼마나 설명하는지 보여준다.
    #
    # 일반적으로:
    #
    # 1에 가까울수록 좋음
    # 0에 가까우면 설명력이 낮음
    # --------------------------------------------------------

    r2 = r2_score(
        y_test,
        predictions,
    )

    print()

    print("=" * 60)

    print(
        "모델 학습 결과"
    )

    print("=" * 60)

    print(
        f"MAE(평균 절대 오차): "
        f"{mae:.2f}분"
    )

    print(
        f"R²(설명력): "
        f"{r2:.4f}"
    )

    # ========================================================
    # Feature 중요도 출력
    # ========================================================

    print()

    print(
        "Feature 중요도"
    )

    feature_importances = sorted(
        zip(
            FEATURE_NAMES,
            model.feature_importances_,
        ),
        key=lambda item: item[1],
        reverse=True,
    )

    for (
        feature_name,
        importance,
    ) in feature_importances:
        print(
            f"- {feature_name}: "
            f"{importance:.4f}"
        )

    # ========================================================
    # 학습 모델 저장
    # ========================================================

    MODEL_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    # 모델만 저장하는 게 아니라
    # 모델 버전과 Feature 이름도 함께 저장한다.
    model_bundle = {
        "model": model,
        "feature_names": FEATURE_NAMES,
        "model_version": (
            "simulation-random-forest-v1"
        ),
    }

    joblib.dump(
        model_bundle,
        MODEL_PATH,
    )

    print()

    print(
        "모델 저장 완료:"
    )

    print(
        MODEL_PATH
    )

    print()

    print(
        "주의:"
    )

    print(
        "현재 모델 성능은 실제 POPQ 주문 데이터가 아니라 "
        "시뮬레이션 데이터 기준입니다."
    )


# ============================================================
# 파일을 직접 실행했을 때만 학습 시작
# ============================================================


if __name__ == "__main__":
    train_model()