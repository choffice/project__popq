import 'package:flutter_test/flutter_test.dart';
import 'package:popq_seller_app/src/features/announcements/seller_announcement_repository.dart';

void main() {
  test('구버전 공지 응답은 pinned를 false로 파싱한다', () {
    final announcement = SellerAnnouncement.fromJson(<String, Object?>{
      'announcementId': 1,
      'storeId': 10,
      'title': '공지',
      'content': '내용',
      'status': 'PUBLISHED',
      'publishedAt': '2026-08-11T00:00:00Z',
      'createdAt': '2026-08-11T00:00:00Z',
      'updatedAt': '2026-08-11T00:00:00Z',
    });

    expect(announcement.pinned, false);
  });
}
