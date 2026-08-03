import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';

class CustomerFindIdScreen extends StatefulWidget {
  const CustomerFindIdScreen({required this.onFindId, super.key});

  final Future<String> Function(String name, String phone) onFindId;

  @override
  State<CustomerFindIdScreen> createState() => _CustomerFindIdScreenState();
}

class _CustomerFindIdScreenState extends State<CustomerFindIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _busy = false;
  String? _errorMessage;
  String? _foundEmail;

  static final _phonePattern = RegExp(r'^01[0-9]-?\d{3,4}-?\d{4}$');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('아이디 찾기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '가입할 때 입력한 이름과\n전화번호를 입력해 주세요.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PopqSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('find-id-name'),
                    controller: _name,
                    decoration: const InputDecoration(labelText: '이름'),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return '이름을 2자 이상 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('find-id-phone'),
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
                  const SizedBox(height: PopqSpacing.md),
                  FilledButton(
                    key: const Key('find-id-submit'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(_busy ? '확인 중...' : '아이디 찾기'),
                  ),
                ],
              ),
            ),
            if (_foundEmail != null) ...[
              const SizedBox(height: PopqSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(PopqSpacing.md),
                  child: Text(
                    '회원님의 아이디는\n$_foundEmail 입니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: PopqSpacing.md),
              OutlinedButton(
                key: const Key('back-to-sign-in'),
                onPressed: () => context.go(CustomerRoutes.signIn),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('로그인하러 가기'),
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _foundEmail = null;
    });
    try {
      final maskedEmail = await widget.onFindId(
        _name.text.trim(),
        _phone.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _foundEmail = maskedEmail;
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
        _errorMessage = '아이디 찾기에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }
}
