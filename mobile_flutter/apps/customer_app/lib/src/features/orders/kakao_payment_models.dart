class KakaoPaymentPreparation {
  const KakaoPaymentPreparation({
    required this.paymentId,
    required this.orderPublicId,
    required this.provider,
    required this.status,
    required this.amount,
    required this.redirectUrl,
    required this.expiresAt,
    required this.reused,
  });

  factory KakaoPaymentPreparation.fromJson(
      Map<String, Object?> json,
      ) {
    final rawRedirectUrl =
    json['redirectUrl'];

    final rawExpiresAt =
    json['expiresAt'];

    return KakaoPaymentPreparation(
      paymentId:
      (json['paymentId'] as num).toInt(),
      orderPublicId:
      json['orderPublicId'] as String,
      provider:
      json['provider'] as String,
      status:
      json['status'] as String,
      amount:
      (json['amount'] as num).toInt(),
      redirectUrl:
      rawRedirectUrl is String
          ? rawRedirectUrl
          : null,
      expiresAt:
      rawExpiresAt is String
          ? DateTime.tryParse(rawExpiresAt)
          : null,
      reused:
      json['reused'] as bool? ?? false,
    );
  }

  final int paymentId;
  final String orderPublicId;
  final String provider;
  final String status;
  final int amount;

  final String? redirectUrl;
  final DateTime? expiresAt;

  final bool reused;

  bool get isPaid => status == 'PAID';

  bool get canOpenPaymentPage {
    return status == 'IN_PROGRESS' &&
        redirectUrl != null &&
        redirectUrl!.trim().isNotEmpty;
  }
}

class KakaoPaymentApproval {
  const KakaoPaymentApproval({
    required this.paymentId,
    required this.orderPublicId,
    required this.provider,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.approvedAmount,
    required this.approvedAt,
    required this.reused,
  });

  factory KakaoPaymentApproval.fromJson(
      Map<String, Object?> json,
      ) {
    final rawApprovedAmount =
    json['approvedAmount'];

    final rawApprovedAt =
    json['approvedAt'];

    return KakaoPaymentApproval(
      paymentId:
      (json['paymentId'] as num).toInt(),
      orderPublicId:
      json['orderPublicId'] as String,
      provider:
      json['provider'] as String,
      paymentMethod:
      json['paymentMethod'] as String,
      paymentStatus:
      json['paymentStatus'] as String,
      orderStatus:
      json['orderStatus'] as String,
      approvedAmount:
      rawApprovedAmount is num
          ? rawApprovedAmount.toInt()
          : null,
      approvedAt:
      rawApprovedAt is String
          ? DateTime.tryParse(rawApprovedAt)
          : null,
      reused:
      json['reused'] as bool? ?? false,
    );
  }

  final int paymentId;
  final String orderPublicId;
  final String provider;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;

  final int? approvedAmount;
  final DateTime? approvedAt;

  final bool reused;

  bool get isPaid {
    return paymentStatus == 'PAID' &&
        orderStatus == 'PLACED';
  }
}