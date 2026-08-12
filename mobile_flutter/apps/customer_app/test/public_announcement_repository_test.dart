import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/announcements/public_announcement_repository.dart';

void main() {
  test('구버전 공개 공지 응답은 pinned를 false로 파싱한다', () {
    final announcement = PublicAnnouncement.fromJson(<String, Object?>{
      'announcementId': 1,
      'storeId': 10,
      'title': '공지',
      'content': '내용',
      'publishedAt': '2026-08-11T00:00:00Z',
    });

    expect(announcement.pinned, false);
  });
}
