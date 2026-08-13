import 'package:flutter/widgets.dart';

Widget buildSellerLocalFileImage(
  String path, {
  double? width,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Builder(
    builder: (context) => errorBuilder?.call(
      context,
      UnsupportedError('Web에서는 파일 경로 이미지를 사용하지 않습니다.'),
      null,
    ) ?? const SizedBox.shrink(),
  );
}
