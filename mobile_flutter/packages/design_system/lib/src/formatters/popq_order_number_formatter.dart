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
