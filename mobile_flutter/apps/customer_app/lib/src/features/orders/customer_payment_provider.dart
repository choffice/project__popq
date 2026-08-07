enum CustomerPaymentProvider {
  tossPayments,
  naverPay,
}

extension CustomerPaymentProviderView on CustomerPaymentProvider {
  String get label {
    return switch (this) {
      CustomerPaymentProvider.tossPayments => '카드·간편결제',
      CustomerPaymentProvider.naverPay => '네이버페이',
    };
  }

  String get description {
    return switch (this) {
      CustomerPaymentProvider.tossPayments =>
        '토스페이먼츠 통합 결제창에서 카드 또는 간편결제를 선택합니다.',
      CustomerPaymentProvider.naverPay =>
        '토스페이먼츠를 통해 네이버페이 결제창으로 바로 이동합니다.',
    };
  }

  bool get usesNaverPayDirect {
    return this == CustomerPaymentProvider.naverPay;
  }

  bool get requiresTossClientKey => true;

  bool get requiresDirectTermsConsent => usesNaverPayDirect;
}
