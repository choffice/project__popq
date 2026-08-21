import 'seller_support_faq.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

abstract interface class SellerSupportRepository {
  Future<List<SellerSupportFaq>> getPopularFaqs();

  Future<List<SellerSupportFaq>> getFaqs({
    String? keyword,
  });

  Future<SellerSupportTicketDetail> createTicket({
    required SellerSupportCategory category,
    required String subject,
    required String content,
  });

  Future<List<SellerSupportTicketSummary>> getMyTickets();

  Future<SellerSupportTicketDetail> getMyTicket(
      int supportTicketId,
      );

  Future<SellerSupportTicketDetail> sendMessage({
    required int supportTicketId,
    required String content,
  });

  Future<SellerSupportTicketDetail> markTicketAsRead(
      int supportTicketId,
      );
}