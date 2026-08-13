enum CustomerSupportCategory {
  account('ACCOUNT', '계정'),
  order('ORDER', '주문'),
  payment('PAYMENT', '결제·환불'),
  coupon('COUPON', '쿠폰'),
  app('APP', '앱 이용'),
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
  inProgress('IN_PROGRESS', '처리 중'),
  answered('ANSWERED', '답변 완료'),
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
  customer('CUSTOMER'),
  admin('ADMIN');

  const CustomerSupportSenderType(this.apiValue);

  final String apiValue;

  static CustomerSupportSenderType fromJson(Object? value) {
    return CustomerSupportSenderType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => CustomerSupportSenderType.customer,
    );
  }
}
