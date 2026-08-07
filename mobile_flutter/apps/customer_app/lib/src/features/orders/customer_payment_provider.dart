enum CustomerPaymentProvider {
  tossPayments,
  kakaoPay,
}

extension CustomerPaymentProviderView
on CustomerPaymentProvider {
  String get label {
    return switch (this) {
      CustomerPaymentProvider.tossPayments => '토스페이먼츠',
      CustomerPaymentProvider.kakaoPay => '카카오페이',
    };
  }

  String get description {
    return switch (this) {
      CustomerPaymentProvider.tossPayments =>
      '카드 결제를 토스페이먼츠로 진행합니다.',
      CustomerPaymentProvider.kakaoPay =>
      '카카오페이 앱 또는 결제 화면으로 진행합니다.',
    };
  }

  bool get requiresTossClientKey {
    return this ==
        CustomerPaymentProvider.tossPayments;
  }
}