import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

class CustomerAppBadgeService {
  const CustomerAppBadgeService._();

  static Future<void> updateBadge(
      int unreadCount,
      ) async {
    if (!_isSupportedPlatform) {
      return;
    }

    final normalizedCount =
    unreadCount < 0 ? 0 : unreadCount;

    try {
      final supported =
      await AppBadgePlus.isSupported();

      if (!supported) {
        return;
      }

      await AppBadgePlus.updateBadge(
        normalizedCount,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Customer 앱 아이콘 배지 변경 실패: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> clearBadge() {
    return updateBadge(0);
  }

  static Future<void> updateFromMessageData(
      Map<String, dynamic> data,
      ) async {
    final rawBadgeCount = data['badgeCount'];

    if (rawBadgeCount == null) {
      return;
    }

    final int? badgeCount;

    if (rawBadgeCount is int) {
      badgeCount = rawBadgeCount;
    } else {
      badgeCount = int.tryParse(
        rawBadgeCount.toString(),
      );
    }

    if (badgeCount == null) {
      debugPrint(
        'Customer 배지 숫자 형식이 올바르지 않습니다: '
            '$rawBadgeCount',
      );
      return;
    }

    await updateBadge(badgeCount);
  }

  static bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform ==
        TargetPlatform.android ||
        defaultTargetPlatform ==
            TargetPlatform.iOS;
  }
}