/// 홈 화면의 임시 이미지 표현 종류입니다.
///
/// 현재 Store API에는 대표 이미지가 없기 때문에
/// 아이콘과 그라데이션을 선택하는 용도로 사용합니다.
///
/// 추후 대표 이미지 URL이 추가되면 이 enum은
/// 삭제하거나 이미지 fallback 용도로만 남길 수 있습니다.
enum CustomerHomeVisualKind {
  taco,
  dessert,
  koreanFood,
  steak,
  membership,
}

/// 기간 한정 팝업·부스의 임시 표시 데이터입니다.
///
/// 실제 Store API 또는 홈 전용 API가 준비되면
/// 이 모델을 API 응답 모델로 교체할 수 있습니다.
class CustomerHomePopupItem {
  const CustomerHomePopupItem({
    required this.title,
    required this.locationLabel,
    required this.periodLabel,
    required this.badgeLabel,
    required this.visualKind,
    this.storeId,
  });

  final String title;
  final String locationLabel;
  final String periodLabel;
  final String badgeLabel;
  final CustomerHomeVisualKind visualKind;

  /// 실제 Store와 연결되는 항목에서만 사용합니다.
  ///
  /// 임시 데이터에는 존재하지 않는 Store ID를
  /// 임의로 넣지 않기 위해 기본값은 null입니다.
  final int? storeId;
}

/// 추천 매장의 임시 표시 데이터입니다.
///
/// 실제 Store API에서 추천 기준이 제공되면
/// 이 모델 대신 실제 매장 목록을 사용합니다.
class CustomerHomeRecommendedItem {
  const CustomerHomeRecommendedItem({
    required this.name,
    required this.categoryLabel,
    required this.rating,
    required this.visualKind,
    this.storeId,
  });

  final String name;
  final String categoryLabel;
  final double rating;
  final CustomerHomeVisualKind visualKind;

  /// 실제 Store와 연결되는 경우에만 사용합니다.
  final int? storeId;
}

/// 회원 혜택 또는 서비스 안내 배너 데이터입니다.
class CustomerHomeBenefitBanner {
  const CustomerHomeBenefitBanner({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.visualKind,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final CustomerHomeVisualKind visualKind;
}

/// 아직 백엔드 API가 없는 홈 전용 임시 콘텐츠입니다.
///
/// 추후 홈 전용 API가 준비되면 이 클래스만 제거하고
/// API 응답으로 교체할 수 있습니다.
///
/// 테스트 매장에는 사용하지 않으며,
/// 테스트 매장은 기존 공개 Store API에서 가져옵니다.
abstract final class CustomerHomeTemporaryContent {
  static const popupItems = <CustomerHomePopupItem>[
    CustomerHomePopupItem(
      title: '부산 야시장 타코 부스',
      locationLabel: '부산 야시장 A구역',
      periodLabel: '8월 10일까지',
      badgeLabel: '기간 한정',
      visualKind: CustomerHomeVisualKind.taco,
    ),
    CustomerHomePopupItem(
      title: '서면 푸드마켓 디저트 부스',
      locationLabel: '서면 푸드마켓',
      periodLabel: '8월 12일까지',
      badgeLabel: '이번 달',
      visualKind: CustomerHomeVisualKind.dessert,
    ),
  ];

  static const recommendedItems =
  <CustomerHomeRecommendedItem>[
    CustomerHomeRecommendedItem(
      name: '서면 분식당',
      categoryLabel: '분식 · 한식',
      rating: 4.6,
      visualKind: CustomerHomeVisualKind.koreanFood,
    ),
    CustomerHomeRecommendedItem(
      name: '그릴하우스',
      categoryLabel: '양식 · 스테이크',
      rating: 4.7,
      visualKind: CustomerHomeVisualKind.steak,
    ),
  ];

  static const benefitBanners =
  <CustomerHomeBenefitBanner>[
    CustomerHomeBenefitBanner(
      eyebrow: 'POPQ MEMBER',
      title: '주문과 관심 매장을\n한곳에서 관리하세요.',
      description:
      '주문 내역, 관심 스토어와 리뷰를 마이페이지에서 확인할 수 있어요.',
      actionLabel: '회원 혜택 보기',
      visualKind: CustomerHomeVisualKind.membership,
    ),
  ];
}