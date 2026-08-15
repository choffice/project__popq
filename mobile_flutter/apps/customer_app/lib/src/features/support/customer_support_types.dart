enum CustomerSupportCategory {
  account('ACCOUNT', '계정'),
  storeVisibility('STORE_VISIBILITY', '매장 노출'),
  orderPayment('ORDER_PAYMENT', '주문·결제'),
  other('OTHER', '기타');

  const CustomerSupportCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CustomerSupportCategory fromJson(Object? value) {
    return CustomerSupportCategory.values.firstWhere(
          (category) => category.apiValue == value,
      orElse: () => CustomerSupportCategory.other,
    );
  }
}

enum CustomerSupportStatus {
  received('RECEIVED', '접수'),
  waitingAdmin('WAITING_ADMIN', '관리자 답변 대기'),
  waitingRequester('WAITING_REQUESTER', '내 답변 대기'),
  closed('CLOSED', '종료');

  const CustomerSupportStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CustomerSupportStatus fromJson(Object? value) {
    return CustomerSupportStatus.values.firstWhere(
          (status) => status.apiValue == value,
      orElse: () => CustomerSupportStatus.received,
    );
  }
}

enum CustomerSupportSenderType {
  requester('REQUESTER'),
  admin('ADMIN');

  const CustomerSupportSenderType(this.apiValue);

  final String apiValue;

  static CustomerSupportSenderType fromJson(Object? value) {
    return CustomerSupportSenderType.values.firstWhere(
          (type) => type.apiValue == value,
      orElse: () => CustomerSupportSenderType.requester,
    );
  }
}