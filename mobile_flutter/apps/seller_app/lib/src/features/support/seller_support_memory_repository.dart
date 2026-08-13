import 'seller_support_faq.dart';
import 'seller_support_repository.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

class MemorySellerSupportRepository implements SellerSupportRepository {
  MemorySellerSupportRepository()
    : _faqs = const [
        SellerSupportFaq(
          faqId: 1,
          audience: 'SELLER',
          category: 'STORE_VISIBILITY',
          question: '매장 정보는 어디에서 수정하나요?',
          answer: '운영 화면의 매장 관리 메뉴에서 매장 정보를 수정할 수 있습니다.',
          displayOrder: 1,
          popular: true,
        ),
        SellerSupportFaq(
          faqId: 2,
          audience: 'SELLER',
          category: 'ORDER_PAYMENT',
          question: '주문을 취소하려면 어떻게 해야 하나요?',
          answer: '주문 상세 화면에서 현재 상태를 확인한 후 취소 또는 거절할 수 있습니다.',
          displayOrder: 2,
          popular: true,
        ),
        SellerSupportFaq(
          faqId: 3,
          audience: 'SELLER',
          category: 'APP',
          question: '알림이 오지 않아요.',
          answer: '기기의 알림 권한과 판매자 앱의 알림 설정을 확인해 주세요.',
          displayOrder: 3,
          popular: true,
        ),
        SellerSupportFaq(
          faqId: 4,
          audience: 'SELLER',
          category: 'ACCOUNT',
          question: '판매자 계정 정보를 변경하고 싶어요.',
          answer: '마이 화면의 프로필 메뉴에서 계정 정보를 확인하고 변경할 수 있습니다.',
          displayOrder: 4,
          popular: false,
        ),
      ],
      _details = {
        1: SellerSupportTicketDetail(
          ticket: SellerSupportTicketSummary(
            supportTicketId: 1,
            requesterType: 'SELLER',
            category: SellerSupportCategory.app,
            subject: '상품 등록 화면이 열리지 않아요',
            status: SellerSupportStatus.waitingRequester,
            lastMessageAt: DateTime(2026, 8, 13, 14, 30),
            createdAt: DateTime(2026, 8, 13, 10),
            unreadMessageCount: 1,
          ),
          messages: [
            SellerSupportMessage(
              supportMessageId: 1,
              senderType: SellerSupportSenderType.seller,
              senderName: '판매자',
              content: '상품 등록 버튼을 누르면 화면이 멈춥니다.',
              createdAt: DateTime(2026, 8, 13, 10),
              readAt: DateTime(2026, 8, 13, 10, 5),
            ),
            SellerSupportMessage(
              supportMessageId: 2,
              senderType: SellerSupportSenderType.admin,
              senderName: 'POPQ 관리자',
              content: '앱을 최신 버전으로 업데이트한 뒤 다시 확인해 주세요.',
              createdAt: DateTime(2026, 8, 13, 14, 30),
            ),
          ],
        ),
        2: SellerSupportTicketDetail(
          ticket: SellerSupportTicketSummary(
            supportTicketId: 2,
            requesterType: 'SELLER',
            category: SellerSupportCategory.storeVisibility,
            subject: '매장이 검색 결과에 나오지 않습니다',
            status: SellerSupportStatus.waitingAdmin,
            lastMessageAt: DateTime(2026, 8, 12, 16),
            createdAt: DateTime(2026, 8, 12, 16),
            unreadMessageCount: 0,
          ),
          messages: [
            SellerSupportMessage(
              supportMessageId: 3,
              senderType: SellerSupportSenderType.seller,
              senderName: '판매자',
              content: '매장 등록을 완료했는데 검색 결과에 나오지 않습니다.',
              createdAt: DateTime(2026, 8, 12, 16),
            ),
          ],
        ),
        3: SellerSupportTicketDetail(
          ticket: SellerSupportTicketSummary(
            supportTicketId: 3,
            requesterType: 'SELLER',
            category: SellerSupportCategory.account,
            subject: '계정 정보 변경 문의',
            status: SellerSupportStatus.closed,
            lastMessageAt: DateTime(2026, 8, 10, 11),
            createdAt: DateTime(2026, 8, 9, 9),
            unreadMessageCount: 0,
          ),
          messages: [
            SellerSupportMessage(
              supportMessageId: 4,
              senderType: SellerSupportSenderType.seller,
              senderName: '판매자',
              content: '전화번호를 변경하고 싶습니다.',
              createdAt: DateTime(2026, 8, 9, 9),
              readAt: DateTime(2026, 8, 9, 9, 10),
            ),
            SellerSupportMessage(
              supportMessageId: 5,
              senderType: SellerSupportSenderType.admin,
              senderName: 'POPQ 관리자',
              content: '프로필 화면에서 전화번호를 변경할 수 있습니다.',
              createdAt: DateTime(2026, 8, 10, 11),
              readAt: DateTime(2026, 8, 10, 12),
            ),
          ],
        ),
      };

  final List<SellerSupportFaq> _faqs;
  final Map<int, SellerSupportTicketDetail> _details;

  int _nextTicketId = 4;
  int _nextMessageId = 6;

  @override
  Future<List<SellerSupportFaq>> getPopularFaqs() async {
    final result = _faqs.where((faq) => faq.popular).toList()
      ..sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );

    return List.unmodifiable(result);
  }

  @override
  Future<List<SellerSupportFaq>> getFaqs({String? keyword}) async {
    final normalizedKeyword = keyword?.trim().toLowerCase() ?? '';

    final result =
        _faqs.where((faq) {
          if (normalizedKeyword.isEmpty) {
            return true;
          }

          return faq.question.toLowerCase().contains(normalizedKeyword) ||
              faq.answer.toLowerCase().contains(normalizedKeyword) ||
              faq.category.toLowerCase().contains(normalizedKeyword);
        }).toList()..sort(
          (first, second) => first.displayOrder.compareTo(second.displayOrder),
        );

    return List.unmodifiable(result);
  }

  @override
  Future<SellerSupportTicketDetail> createTicket({
    required SellerSupportCategory category,
    required String subject,
    required String content,
  }) async {
    final normalizedSubject = subject.trim();
    final normalizedContent = content.trim();

    _validateSubject(normalizedSubject);
    _validateContent(normalizedContent);

    final now = DateTime.now();
    final ticketId = _nextTicketId++;
    final messageId = _nextMessageId++;

    final detail = SellerSupportTicketDetail(
      ticket: SellerSupportTicketSummary(
        supportTicketId: ticketId,
        requesterType: 'SELLER',
        category: category,
        subject: normalizedSubject,
        status: SellerSupportStatus.received,
        lastMessageAt: now,
        createdAt: now,
        unreadMessageCount: 0,
      ),
      messages: [
        SellerSupportMessage(
          supportMessageId: messageId,
          senderType: SellerSupportSenderType.seller,
          senderName: '판매자',
          content: normalizedContent,
          createdAt: now,
        ),
      ],
    );

    _details[ticketId] = detail;

    return detail;
  }

  @override
  Future<List<SellerSupportTicketSummary>> getMyTickets() async {
    final tickets = _details.values.map((detail) => detail.ticket).toList()
      ..sort(
        (first, second) => second.lastMessageAt.compareTo(first.lastMessageAt),
      );

    return List.unmodifiable(tickets);
  }

  @override
  Future<SellerSupportTicketDetail> getMyTicket(int supportTicketId) async {
    return _findTicket(supportTicketId);
  }

  @override
  Future<SellerSupportTicketDetail> sendMessage({
    required int supportTicketId,
    required String content,
  }) async {
    final current = _findTicket(supportTicketId);

    if (current.ticket.status == SellerSupportStatus.closed) {
      throw StateError('종료된 문의에는 메시지를 보낼 수 없습니다.');
    }

    final normalizedContent = content.trim();
    _validateContent(normalizedContent);

    final now = DateTime.now();

    final updatedTicket = _copyTicket(
      current.ticket,
      status: SellerSupportStatus.waitingAdmin,
      lastMessageAt: now,
      unreadMessageCount: 0,
    );

    final updatedDetail = SellerSupportTicketDetail(
      ticket: updatedTicket,
      messages: List.unmodifiable([
        ...current.messages,
        SellerSupportMessage(
          supportMessageId: _nextMessageId++,
          senderType: SellerSupportSenderType.seller,
          senderName: '판매자',
          content: normalizedContent,
          createdAt: now,
        ),
      ]),
    );

    _details[supportTicketId] = updatedDetail;

    return updatedDetail;
  }

  @override
  Future<SellerSupportTicketDetail> markTicketAsRead(
    int supportTicketId,
  ) async {
    final current = _findTicket(supportTicketId);
    final now = DateTime.now();

    final updatedMessages = current.messages
        .map((message) {
          if (!message.sentByAdmin || message.readAt != null) {
            return message;
          }

          return SellerSupportMessage(
            supportMessageId: message.supportMessageId,
            senderType: message.senderType,
            senderName: message.senderName,
            content: message.content,
            createdAt: message.createdAt,
            readAt: now,
          );
        })
        .toList(growable: false);

    final updatedDetail = SellerSupportTicketDetail(
      ticket: _copyTicket(current.ticket, unreadMessageCount: 0),
      messages: updatedMessages,
    );

    _details[supportTicketId] = updatedDetail;

    return updatedDetail;
  }

  SellerSupportTicketDetail _findTicket(int supportTicketId) {
    if (supportTicketId <= 0) {
      throw ArgumentError.value(
        supportTicketId,
        'supportTicketId',
        '문의 번호는 1 이상이어야 합니다.',
      );
    }

    final detail = _details[supportTicketId];

    if (detail == null) {
      throw StateError('문의 내용을 찾을 수 없습니다.');
    }

    return detail;
  }

  SellerSupportTicketSummary _copyTicket(
    SellerSupportTicketSummary source, {
    SellerSupportStatus? status,
    DateTime? lastMessageAt,
    int? unreadMessageCount,
  }) {
    return SellerSupportTicketSummary(
      supportTicketId: source.supportTicketId,
      requesterType: source.requesterType,
      category: source.category,
      subject: source.subject,
      status: status ?? source.status,
      lastMessageAt: lastMessageAt ?? source.lastMessageAt,
      createdAt: source.createdAt,
      unreadMessageCount: unreadMessageCount ?? source.unreadMessageCount,
    );
  }

  void _validateSubject(String subject) {
    if (subject.isEmpty) {
      throw ArgumentError('문의 제목을 입력해 주세요.');
    }

    if (subject.length > 200) {
      throw ArgumentError('문의 제목은 200자 이하로 입력해 주세요.');
    }
  }

  void _validateContent(String content) {
    if (content.isEmpty) {
      throw ArgumentError('문의 내용을 입력해 주세요.');
    }

    if (content.length > 4000) {
      throw ArgumentError('문의 내용은 4000자 이하로 입력해 주세요.');
    }
  }
}
