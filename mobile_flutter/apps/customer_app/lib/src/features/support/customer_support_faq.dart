class CustomerSupportFaq {
  const CustomerSupportFaq({
    required this.faqId,
    required this.audience,
    required this.category,
    required this.question,
    required this.answer,
    required this.displayOrder,
  });

  factory CustomerSupportFaq.fromJson(Map<String, Object?> json) {
    return CustomerSupportFaq(
      faqId: (json['faqId'] as num).toInt(),
      audience: json['audience'] as String,
      category: json['category'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
    );
  }

  final int faqId;
  final String audience;
  final String category;
  final String question;
  final String answer;
  final int displayOrder;
}