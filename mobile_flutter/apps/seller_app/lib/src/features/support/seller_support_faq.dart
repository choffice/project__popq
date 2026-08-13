class SellerSupportFaq {
  const SellerSupportFaq({
    required this.faqId,
    required this.audience,
    required this.category,
    required this.question,
    required this.answer,
    required this.displayOrder,
    required this.popular,
  });

  factory SellerSupportFaq.fromJson(Map<String, Object?> json) {
    return SellerSupportFaq(
      faqId: (json['faqId'] as num).toInt(),
      audience: json['audience'] as String,
      category: json['category'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
      popular: json['popular'] as bool,
    );
  }

  final int faqId;
  final String audience;
  final String category;
  final String question;
  final String answer;
  final int displayOrder;
  final bool popular;
}
