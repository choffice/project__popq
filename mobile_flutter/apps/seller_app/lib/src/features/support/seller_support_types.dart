enum SellerSupportCategory {
  account('ACCOUNT', '계정'),
  storeVisibility('STORE_VISIBILITY', '매장 관리·노출'),
  orderPayment('ORDER_PAYMENT', '주문·결제'),
  other('OTHER', '기타');

  const SellerSupportCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SellerSupportCategory fromJson(Object? value) {
    return SellerSupportCategory.values.firstWhere(
      (category) => category.apiValue == value,
      orElse: () => SellerSupportCategory.other,
    );
  }
}

enum SellerSupportStatus {
  received('RECEIVED', '접수'),
  waitingAdmin('WAITING_ADMIN', '관리자 답변 대기'),
  waitingRequester('WAITING_REQUESTER', '판매자 답변 대기'),
  closed('CLOSED', '종료');

  const SellerSupportStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SellerSupportStatus fromJson(Object? value) {
    return SellerSupportStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => SellerSupportStatus.received,
    );
  }
}

enum SellerSupportSenderType {
  requester('REQUESTER'),
  admin('ADMIN');

  const SellerSupportSenderType(this.apiValue);

  final String apiValue;

  static SellerSupportSenderType fromJson(Object? value) {
    return SellerSupportSenderType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => SellerSupportSenderType.requester,
    );
  }
}
