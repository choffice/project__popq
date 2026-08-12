class CustomerSupportFaq {
  const CustomerSupportFaq({
    required this.supportFaqId,
    required this.question,
    required this.answer,
    required this.displayOrder,
    required this.viewCount,
    required this.popular,
  });

  factory CustomerSupportFaq.fromJson(Map<String, Object?> json) {
    return CustomerSupportFaq(
      supportFaqId: (json['supportFaqId'] as num).toInt(),
      question: json['question'] as String,
      answer: json['answer'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
      viewCount: (json['viewCount'] as num).toInt(),
      popular: json['popular'] as bool,
    );
  }

  final int supportFaqId;
  final String question;
  final String answer;
  final int displayOrder;
  final int viewCount;
  final bool popular;
}
