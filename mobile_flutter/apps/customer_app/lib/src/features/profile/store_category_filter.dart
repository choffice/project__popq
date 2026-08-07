/// 매장 등록 시 선택하는 대표 카테고리 값 중 "식당"으로 묶이는 값들입니다.
const List<String> _foodRepresentativeCategories = <String>[
  '한식',
  '중식',
  '일식',
  '양식',
  '분식',
  '치킨',
  '피자',
  '패스트푸드',
  '주점',
  '디저트',
  '베이커리',
];

/// 홈 화면 카테고리 탭 라벨(전체/식당/팝업스토어/플리마켓/푸드트럭/카페)과
/// 매장의 실제 대표 카테고리 값을 매칭합니다.
bool matchesStoreCategoryLabel(String? representativeCategory, String label) {
  if (label == '전체') return true;

  final category = representativeCategory?.trim() ?? '';

  return switch (label) {
    '식당' => _foodRepresentativeCategories.contains(category),
    '팝업스토어' => category == '팝업·행사',
    '플리마켓' => category == '플리마켓·행사',
    '푸드트럭' => category == '푸드트럭',
    '카페' => category == '카페',
    _ => category == label,
  };
}
