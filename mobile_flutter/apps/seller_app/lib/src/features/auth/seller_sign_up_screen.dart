import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';

class SellerSignUpScreen extends StatefulWidget {
  const SellerSignUpScreen({
    required this.onSignUp,
    required this.onSendEmailVerificationCode,
    required this.onVerifyEmailCode,
    super.key,
  });

  final Future<void> Function({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String emailVerificationToken,
  })
  onSignUp;
  final Future<void> Function(String email) onSendEmailVerificationCode;
  final Future<String> Function(String email, String code) onVerifyEmailCode;

  @override
  State<SellerSignUpScreen> createState() => _SellerSignUpScreenState();
}

class _SellerSignUpScreenState extends State<SellerSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _emailCode = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _busy = false;
  var _sendingCode = false;
  var _agreed = false;
  String? _emailVerificationToken;
  String? _errorMessage;

  static final _passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$');
  static final _phonePattern = RegExp(r'^01[0-9]-?\d{3,4}-?\d{4}$');
  static final _nicknamePattern = RegExp(
    r'^[A-Za-z0-9 \u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7A3\u3131-\u318E]+$',
    unicode: true,
  );

  @override
  void dispose() {
    _email.dispose();
    _emailCode.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('판매자 회원가입')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '판매자 계정을 만들어\n스토어 운영을 시작하세요.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PopqSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('sign-up-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '이메일'),
                    validator: AuthInputValidator.validateEmail,
                    onChanged: (_) {
                      if (_emailVerificationToken != null) {
                        setState(() {
                          _emailVerificationToken = null;
                          _emailCode.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  OutlinedButton(
                    key: const Key('sign-up-send-email-code'),
                    onPressed: _sendingCode || _emailVerificationToken != null
                        ? null
                        : _sendEmailCode,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _emailVerificationToken != null
                          ? '이메일 인증 완료'
                          : _sendingCode
                          ? '발송 중...'
                          : '인증번호 발송',
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('sign-up-name'),
                    controller: _name,
                    maxLength: 7,
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      hintText: '한글·영문·숫자·일본어·한자, 7자 이하',
                      counterText: '',
                    ),
                    validator: (value) {
                      final nickname = value?.trim() ?? '';
                      if (nickname.isEmpty) {
                        return '닉네임을 입력해 주세요.';
                      }
                      if (nickname.length > 7) {
                        return '닉네임은 7자 이하로 입력해 주세요.';
                      }
                      if (!_nicknamePattern.hasMatch(nickname)) {
                        return '사용할 수 없는 문자가 포함되어 있어요.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    key: const Key('sign-up-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '전화번호',
                      hintText: '010-1234-5678',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '전화번호를 입력해 주세요.';
                      }
                      if (!_phonePattern.hasMatch(value.trim())) {
                        return '올바른 전화번호 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('sign-up-password'),
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      hintText: '영문·숫자 포함 8자 이상',
                    ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return '비밀번호는 8자 이상이어야 합니다.';
                      }
                      if (!_passwordPattern.hasMatch(value)) {
                        return '비밀번호는 영문과 숫자를 포함해야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('sign-up-password-confirm'),
                    controller: _passwordConfirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '비밀번호 확인'),
                    validator: (value) {
                      if (value != _password.text) {
                        return '비밀번호가 일치하지 않습니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  Row(
                    children: [
                      Checkbox(
                        key: const Key('sign-up-agree'),
                        value: _agreed,
                        onChanged: (value) {
                          setState(() => _agreed = value ?? false);
                        },
                      ),
                      const Expanded(
                        child: Text('이용약관 및 개인정보 처리방침에 동의합니다. (필수)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  FilledButton(
                    key: const Key('sign-up-submit'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(_busy ? '가입 처리 중...' : '회원가입'),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: PopqSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PopqPalette.coral),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final emailVerificationToken = _emailVerificationToken;
    if (emailVerificationToken == null) {
      setState(() => _errorMessage = '이메일 인증을 완료해 주세요.');
      return;
    }
    if (!_agreed) {
      setState(() => _errorMessage = '필수 약관에 동의해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await widget.onSignUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        emailVerificationToken: emailVerificationToken,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해 주세요.')),
      );
      context.go(SellerRoutes.signIn);
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = '회원가입에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _sendEmailCode() async {
    final emailError = AuthInputValidator.validateEmail(_email.text);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sendingCode = true;
      _errorMessage = null;
      _emailVerificationToken = null;
      _emailCode.clear();
    });
    try {
      await widget.onSendEmailVerificationCode(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
      });
      final token = await _showEmailVerificationDialog(_email.text.trim());
      if (!mounted || token == null) return;
      setState(() {
        _emailVerificationToken = token;
      });
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('이메일 인증이 완료되었습니다.')));
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _errorMessage = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _errorMessage = '인증번호를 발송하지 못했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<String?> _showEmailVerificationDialog(String email) {
    _emailCode.clear();
    var verifying = false;
    String? dialogError;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('이메일 인증'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$email\n이메일로 전송된 인증번호를 입력해 주세요.'),
                  const SizedBox(height: PopqSpacing.md),
                  TextField(
                    key: const Key('sign-up-email-code-dialog'),
                    controller: _emailCode,
                    autofocus: true,
                    enabled: !verifying,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: '인증번호',
                      hintText: '숫자 6자리',
                      errorText: dialogError,
                      counterText: '',
                    ),
                    maxLength: 6,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: verifying
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const Key('sign-up-verify-email-code-dialog'),
                  onPressed: verifying
                      ? null
                      : () async {
                          if (_emailCode.text.length != 6) {
                            setDialogState(() {
                              dialogError = '인증번호 6자리를 입력해 주세요.';
                            });
                            return;
                          }
                          setDialogState(() {
                            verifying = true;
                            dialogError = null;
                          });
                          try {
                            final token = await widget.onVerifyEmailCode(
                              email,
                              _emailCode.text,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(token);
                          } on PopqFailure catch (failure) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              verifying = false;
                              dialogError = failure.message;
                            });
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              verifying = false;
                              dialogError = '인증번호를 확인하지 못했습니다.';
                            });
                          }
                        },
                  child: Text(verifying ? '확인 중...' : '확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
