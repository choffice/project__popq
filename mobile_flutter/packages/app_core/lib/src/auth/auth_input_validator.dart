class AuthInputValidator {
  AuthInputValidator._();

  static final RegExp _emailPattern = RegExp(
    r"^(?=.{1,255}$)[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,63}$",
  );

  static bool isValidEmail(String value) {
    return _emailPattern.hasMatch(value.trim());
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이메일을 입력해 주세요.';
    }
    if (!isValidEmail(value)) {
      return '올바른 이메일 형식이 아닙니다.';
    }
    return null;
  }
}
