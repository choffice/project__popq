import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';

class CustomerSignUpScreen extends StatefulWidget {
  const CustomerSignUpScreen({required this.onSignUp, super.key});

  final Future<void> Function({
    required String email,
    required String password,
    required String name,
    required String phone,
  })
  onSignUp;

  @override
  State<CustomerSignUpScreen> createState() =>
      _CustomerSignUpScreenState();
}

class _CustomerSignUpScreenState extends State<CustomerSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _busy = false;
  var _agreed = false;
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
      appBar: AppBar(title: const Text('?뚯썝媛??)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '?뚯썝媛?낇븯怨?nPOPQ瑜??댁뼱??利먭꺼蹂댁꽭??',
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
                    decoration: const InputDecoration(labelText: '?대찓??),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '?대찓?쇱쓣 ?낅젰??二쇱꽭??';
                      }
                      if (!value.contains('@')) {
                        return '?щ컮瑜??대찓???뺤떇???꾨떃?덈떎.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('sign-up-name'),
                    controller: _name,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: '?대쫫'),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return '?대쫫??2???댁긽 ?낅젰??二쇱꽭??';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    key: const Key('sign-up-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '?꾪솕踰덊샇',
                      hintText: '010-1234-5678',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '?꾪솕踰덊샇瑜??낅젰??二쇱꽭??';
                      }
                      if (!_phonePattern.hasMatch(value.trim())) {
                        return '?щ컮瑜??꾪솕踰덊샇 ?뺤떇???꾨떃?덈떎.';
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
                      labelText: '鍮꾨?踰덊샇',
                      helperText: '?곷Ц怨??レ옄瑜??ы븿??8???댁긽 ?낅젰??二쇱꽭??',
                    ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return '鍮꾨?踰덊샇??8???댁긽?댁뼱???⑸땲??';
                      }
                      if (!_passwordPattern.hasMatch(value)) {
                        return '鍮꾨?踰덊샇???곷Ц怨??レ옄瑜??ы븿?댁빞 ?⑸땲??';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('sign-up-password-confirm'),
                    controller: _passwordConfirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '鍮꾨?踰덊샇 ?뺤씤'),
                    validator: (value) {
                      if (value != _password.text) {
                        return '鍮꾨?踰덊샇媛 ?쇱튂?섏? ?딆뒿?덈떎.';
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
                      const Text('?곗씠?????멸쾶??),
                    ],
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  FilledButton(
                    key: const Key('sign-up-submit'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(_busy ? '媛??泥섎━ 以?..' : '?뚯썝媛??),
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
    if (!_agreed) {
      setState(() => _errorMessage = '?곗씠???댁슜???숈쓽??二쇱꽭??');
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
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('?뚯썝媛?낆씠 ?꾨즺?섏뿀?듬땲?? 濡쒓렇?명빐 二쇱꽭??')),
      );
      context.go(CustomerRoutes.signIn);
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
        _errorMessage = '?뚯썝媛?낆뿉 ?ㅽ뙣?덉뒿?덈떎. ?ㅼ떆 ?쒕룄??二쇱꽭??';
      });
    }
  }
}

