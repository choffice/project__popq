/// 주문의 실제 식별자는 변경하지 않고 화면 표시용으로만 짧게 만듭니다.
///
/// 예시:
/// `15c495bf-9c8e-4869-91d4-81574eb6f4b4`
/// → `주문번호 #15C495BF`
String formatPopqOrderNumber(
  String orderPublicId, {
  bool includeLabel = true,
  int visibleLength = 8,
}) {
  final normalized = orderPublicId.trim();

  if (normalized.isEmpty) {
    return includeLabel ? '주문번호 없음' : '#-';
  }

  final safeLength = visibleLength < 1 ? 1 : visibleLength;
  final shortId = normalized.length <= safeLength
      ? normalized
      : normalized.substring(0, safeLength);
  final formatted = '#${shortId.toUpperCase()}';

  return includeLabel ? '주문번호 $formatted' : formatted;
}

/// 주문 목록에서 대표 상품을 최대 [visibleItemCount]종까지 표시합니다.
///
/// 각 항목은 호출하는 화면에서 `상품명 수량개` 형식으로 전달합니다.
/// 예시:
/// `아메리카노 2개, 딸기 크로플 1개 외 2종`
String formatPopqOrderItemSummary(
  Iterable<String> itemLabels, {
  int visibleItemCount = 2,
  String emptyLabel = '주문 상품 없음',
}) {
  final labels = itemLabels
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .toList(growable: false);

  if (labels.isEmpty) {
    return emptyLabel;
  }

  final safeVisibleCount = visibleItemCount < 1 ? 1 : visibleItemCount;
  final visibleLabels = labels.take(safeVisibleCount).join(', ');
  final remainingCount = labels.length - safeVisibleCount;

  if (remainingCount <= 0) {
    return visibleLabels;
  }

  return '$visibleLabels 외 $remainingCount종';
}
