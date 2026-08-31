/// 회원 혜택 또는 서비스 안내 배너 데이터입니다.
///
/// 특정 매장이나 이벤트를 가장하지 않는 서비스 안내 콘텐츠이므로
/// 홈의 정적 안내 배너로 사용합니다.
class CustomerHomeBenefitBanner {
  const CustomerHomeBenefitBanner({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
}

/// 실제 매장 데이터와 무관한 POPQ 서비스 안내 콘텐츠입니다.
///
/// 매장·이벤트·추천 목록은 이 파일에서 만들지 않고 Store API 결과만 사용합니다.
abstract final class CustomerHomeContent {
  static const List<CustomerHomeBenefitBanner> benefitBanners =
      <CustomerHomeBenefitBanner>[
    CustomerHomeBenefitBanner(
      eyebrow: 'POPQ MEMBER',
      title: '주문과 관심 매장을\n한곳에서 관리하세요.',
      description:
          '주문 내역, 관심 스토어와 리뷰를 마이페이지에서 확인할 수 있어요.',
      actionLabel: '회원 혜택 보기',
    ),
  ];
}
