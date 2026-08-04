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
  popupMarket,
  cafe,
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
    this.dDayLabel,
    this.storeId,
  });

  final String title;
  final String locationLabel;
  final String periodLabel;
  final String badgeLabel;
  final CustomerHomeVisualKind visualKind;

  /// 진행 중인 이벤트 카드에 표시하는 D-day 배지입니다.
  ///
  /// 실제 Store와 연결된 이벤트에는 종료일 정보가 없어
  /// null일 수 있습니다.
  final String? dDayLabel;

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
    this.visitLabel,
    this.storeId,
  });

  final String name;
  final String categoryLabel;
  final double rating;
  final CustomerHomeVisualKind visualKind;

  /// 인기 랭킹 카드에 표시하는 방문 횟수 텍스트입니다.
  final String? visitLabel;

  /// 실제 Store와 연결되는 경우에만 사용합니다.
  final int? storeId;
}

/// 이번 주 추천 이벤트 캐러셀에 사용하는 임시 표시 데이터입니다.
class CustomerHomeFeatureBanner {
  const CustomerHomeFeatureBanner({
    required this.title,
    required this.description,
    required this.periodLabel,
    required this.locationLabel,
    required this.visualKind,
  });

  final String title;
  final String description;
  final String periodLabel;
  final String locationLabel;
  final CustomerHomeVisualKind visualKind;
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

/// 인기 랭킹·진행 중인 이벤트가 기준으로 삼는 권역입니다.
///
/// 현재 서비스는 부산 지역만 지원합니다.
enum CustomerHomeRegion {
  busan,
}

/// 아직 백엔드 API가 없는 홈 전용 임시 콘텐츠입니다.
///
/// 추후 홈 전용 API가 준비되면 이 클래스만 제거하고
/// API 응답으로 교체할 수 있습니다.
///
/// 테스트 매장에는 사용하지 않으며,
/// 테스트 매장은 기존 공개 Store API에서 가져옵니다.
abstract final class CustomerHomeTemporaryContent {
  static String regionLabel(
      CustomerHomeRegion region,
      ) {
    return switch (region) {
      CustomerHomeRegion.busan => '부산',
    };
  }

  static List<CustomerHomePopupItem> popupItemsFor(
      CustomerHomeRegion region,
      ) {
    return switch (region) {
      CustomerHomeRegion.busan => _busanPopupItems,
    };
  }

  static List<CustomerHomeRecommendedItem>
  recommendedItemsFor(
      CustomerHomeRegion region,
      ) {
    return switch (region) {
      CustomerHomeRegion.busan =>
      _busanRecommendedItems,
    };
  }

  static const _busanPopupItems =
  <CustomerHomePopupItem>[
    CustomerHomePopupItem(
      title: '부산 야시장 타코 부스',
      locationLabel: '부산 야시장 A구역',
      periodLabel: '8월 10일까지',
      badgeLabel: '기간 한정',
      dDayLabel: 'D-2',
      visualKind: CustomerHomeVisualKind.taco,
    ),
    CustomerHomePopupItem(
      title: '서면 푸드마켓 디저트 부스',
      locationLabel: '서면 푸드마켓',
      periodLabel: '8월 12일까지',
      badgeLabel: '이번 달',
      dDayLabel: 'D-5',
      visualKind: CustomerHomeVisualKind.dessert,
    ),
    CustomerHomePopupItem(
      title: '해운대 플리마켓 팝업존',
      locationLabel: '해운대 해변로',
      periodLabel: '8월 15일까지',
      badgeLabel: '주말 한정',
      dDayLabel: 'D-7',
      visualKind: CustomerHomeVisualKind.popupMarket,
    ),
  ];

  static const _busanRecommendedItems =
  <CustomerHomeRecommendedItem>[
    CustomerHomeRecommendedItem(
      name: '서면 분식당',
      categoryLabel: '분식 · 한식',
      rating: 4.6,
      visitLabel: '142회 방문',
      visualKind: CustomerHomeVisualKind.koreanFood,
    ),
    CustomerHomeRecommendedItem(
      name: '남포동 플리마켓',
      categoryLabel: '플리마켓',
      rating: 4.5,
      visitLabel: '89회 방문',
      visualKind: CustomerHomeVisualKind.membership,
    ),
    CustomerHomeRecommendedItem(
      name: '부산진 타코존',
      categoryLabel: '푸드트럭 · 타코',
      rating: 4.4,
      visitLabel: '77회 방문',
      visualKind: CustomerHomeVisualKind.taco,
    ),
    CustomerHomeRecommendedItem(
      name: '그릴하우스',
      categoryLabel: '양식 · 스테이크',
      rating: 4.7,
      visitLabel: '70회 방문',
      visualKind: CustomerHomeVisualKind.steak,
    ),
    CustomerHomeRecommendedItem(
      name: '해운대 카페 웨이브',
      categoryLabel: '카페',
      rating: 4.5,
      visitLabel: '61회 방문',
      visualKind: CustomerHomeVisualKind.cafe,
    ),
  ];

  static const featureBanners =
  <CustomerHomeFeatureBanner>[
    CustomerHomeFeatureBanner(
      title: '해운대 푸드트럭 페스티벌',
      description: '다양한 음식과 공연을 한곳에서 즐겨보세요!',
      periodLabel: '8월 8일 - 8월 9일',
      locationLabel: '해운대 해변로',
      visualKind: CustomerHomeVisualKind.taco,
    ),
    CustomerHomeFeatureBanner(
      title: '서면 플리마켓 시즌 2',
      description: '로컬 셀러들의 소품과 먹거리를 만나보세요.',
      periodLabel: '8월 10일 - 8월 12일',
      locationLabel: '서면 푸드마켓',
      visualKind: CustomerHomeVisualKind.popupMarket,
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