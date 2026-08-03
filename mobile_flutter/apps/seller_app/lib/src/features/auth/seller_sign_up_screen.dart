import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';

class SellerSignUpScreen extends StatefulWidget {
  const SellerSignUpScreen({required this.onSignUp, super.key});

  final Future<void> Function({
    required String email,
    required String password,
    required String name,
    required String phone,
  })
  onSignUp;

  @override
  State<SellerSignUpScreen> createState() => _SellerSignUpScreenState();
}

class _SellerSignUpScreenState extends State<SellerSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _busy = false;
  String? _errorMessage;

  static final _passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$');
  static final _phonePattern = RegExp(r'^01[0-9]-?\d{3,4}-?\d{4}$');

  @override
  void dispose() {
    _email.dispose();
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일을 입력해 주세요.';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('sign-up-name'),
                    controller: _name,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: '이름 (담당자명)'),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return '이름을 2자 이상 입력해 주세요.';
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
                      helperText: '영문과 숫자를 포함해 8자 이상 입력해 주세요.',
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
                  const SizedBox(height: PopqSpacing.md),
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
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
}
