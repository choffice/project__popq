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
      appBar: AppBar(title: const Text('鍮꾨?踰덊샇 李얘린')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            Text(
              '媛?낇븷 ???낅젰???꾩씠???대찓???\n?꾪솕踰덊샇瑜??낅젰??二쇱꽭??',
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
                    decoration: const InputDecoration(labelText: '?꾩씠??(?대찓??'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '?꾩씠?붾? ?낅젰??二쇱꽭??';
                      }
                      if (!value.contains('@')) {
                        return '?щ컮瑜??대찓???뺤떇???꾨떃?덈떎.';
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
                  if (!_verified) ...[
                    const SizedBox(height: PopqSpacing.md),
                    FilledButton(
                      key: const Key('find-password-verify'),
                      onPressed: _busy ? null : _verify,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(_busy ? '?뺤씤 以?..' : '?뺤씤'),
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
                '??鍮꾨?踰덊샇瑜??낅젰??二쇱꽭??',
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
                        labelText: '??鍮꾨?踰덊샇',
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
                      key: const Key('find-password-new-confirm'),
                      controller: _newPasswordConfirm,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '??鍮꾨?踰덊샇 ?뺤씤'),
                      validator: (value) {
                        if (value != _newPassword.text) {
                          return '鍮꾨?踰덊샇媛 ?쇱튂?섏? ?딆뒿?덈떎.';
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
                      child: Text(_busy ? '蹂寃?以?..' : '鍮꾨?踰덊샇 蹂寃?),
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
        _errorMessage = '?뺤씤???ㅽ뙣?덉뒿?덈떎. ?ㅼ떆 ?쒕룄??二쇱꽭??';
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
        const SnackBar(content: Text('鍮꾨?踰덊샇媛 蹂寃쎈릺?덉뒿?덈떎. 濡쒓렇?명빐 二쇱꽭??')),
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
        _errorMessage = '鍮꾨?踰덊샇 蹂寃쎌뿉 ?ㅽ뙣?덉뒿?덈떎. ?ㅼ떆 ?쒕룄??二쇱꽭??';
      });
    }
  }
}

