import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';

class SellerFindPasswordScreen extends StatefulWidget {
  const SellerFindPasswordScreen({
    required this.onVerify,
    required this.onResetPassword,
    super.key,
  });

  final Future<void> Function(String email, String phone) onVerify;
  final Future<void> Function(String email, String phone, String newPassword)
  onResetPassword;

  @override
  State<SellerFindPasswordScreen> createState() =>
      _SellerFindPasswordScreenState();
}

class _SellerFindPasswordScreenState extends State<SellerFindPasswordScreen> {
  final _verifyFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordConfirm = TextEditingController();
  var _busy = false;
  var _verified = false;
  String? _errorMessage;

  static final _phonePattern = RegExp(r'^01[0-9]-?\d{3,4}-?\d{4}$');
  static final _passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$');

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _newPassword.dispose();
    _newPasswordConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '가입할 때 입력한 아이디(이메일)와\n전화번호를 입력해 주세요.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PopqSpacing.lg),
            Form(
              key: _verifyFormKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('find-password-email'),
                    controller: _email,
                    enabled: !_verified,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '아이디 (이메일)'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '아이디를 입력해 주세요.';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('find-password-phone'),
                    controller: _phone,
                    enabled: !_verified,
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
                  if (!_verified) ...[
                    const SizedBox(height: PopqSpacing.md),
                    FilledButton(
                      key: const Key('find-password-verify'),
                      onPressed: _busy ? null : _verify,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(_busy ? '확인 중...' : '확인'),
                    ),
                  ],
                ],
              ),
            ),
            if (_verified) ...[
              const SizedBox(height: PopqSpacing.lg),
              const Divider(),
              const SizedBox(height: PopqSpacing.md),
              Text(
                '새 비밀번호를 입력해 주세요.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: PopqSpacing.md),
              Form(
                key: _resetFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('find-password-new'),
                      controller: _newPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '새 비밀번호',
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
                      key: const Key('find-password-new-confirm'),
                      controller: _newPasswordConfirm,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                      validator: (value) {
                        if (value != _newPassword.text) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: PopqSpacing.md),
                    FilledButton(
                      key: const Key('find-password-submit'),
                      onPressed: _busy ? null : _submitReset,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(_busy ? '변경 중...' : '비밀번호 변경'),
                    ),
                  ],
                ),
              ),
            ],
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

  Future<void> _verify() async {
    if (!(_verifyFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await widget.onVerify(_email.text.trim(), _phone.text.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _verified = true;
      });
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
        _errorMessage = '확인에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _submitReset() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await widget.onResetPassword(
        _email.text.trim(),
        _phone.text.trim(),
        _newPassword.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다. 로그인해 주세요.')),
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
        _errorMessage = '비밀번호 변경에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }
}
