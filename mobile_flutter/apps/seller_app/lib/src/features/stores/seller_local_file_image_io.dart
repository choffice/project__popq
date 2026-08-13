import 'dart:io';

import 'package:flutter/widgets.dart';

Widget buildSellerLocalFileImage(
  String path, {
  double? width,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Image.file(
    File(path),
    width: width,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
