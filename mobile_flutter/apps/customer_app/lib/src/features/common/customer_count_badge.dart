import 'package:flutter/material.dart';

/// 구매자 앱에서 숫자형 배지를 동일한 위치와 크기로 표시하기 위한 공통 위젯입니다.
///
/// 장바구니, 알림처럼 아이콘 위에 개수를 표시하는 곳에서 사용합니다.
class CustomerCountBadge extends StatelessWidget {
  const CustomerCountBadge({
    required this.count,
    required this.child,
    super.key,
  });

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final badgeText = count > 99 ? '99+' : count.toString();

    return Badge(
      isLabelVisible: count > 0,
      alignment: Alignment.topRight,
      offset: const Offset(-6, 6),
      largeSize: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      textStyle: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
      label: Text(badgeText),
      child: child,
    );
  }
}
