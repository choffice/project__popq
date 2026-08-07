import 'package:flutter/material.dart';

enum PopqImageSource { camera, gallery }

Future<PopqImageSource?> showPopqImageSourceSheet(
  BuildContext context, {
  String cameraLabel = '카메라로 촬영',
  String galleryLabel = '갤러리에서 선택',
}) {
  return showModalBottomSheet<PopqImageSource>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(cameraLabel),
            onTap: () =>
                Navigator.of(sheetContext).pop(PopqImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(galleryLabel),
            onTap: () =>
                Navigator.of(sheetContext).pop(PopqImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.close_rounded),
            title: const Text('취소'),
            onTap: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}
