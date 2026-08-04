import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';

class SellerSignInScreen extends StatefulWidget {
  const SellerSignInScreen({
    required this.roleMismatch,
    required this.onSignIn,
    this.onDevelopmentSignIn,
    this.onGoogleSignIn,
    this.onKakaoSignIn,
    this.onNaverSignIn,
    super.key,
  });

  final bool roleMismatch;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function()? onDevelopmentSignIn;
  final Future<void> Function()? onGoogleSignIn;
  final Future<void> Function()? onKakaoSignIn;
  final Future<void> Function()? onNaverSignIn;

  @override
  State<SellerSignInScreen> createState() => _SellerSignInScreenState();
}

class _SellerSignInScreenState extends State<SellerSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            const SizedBox(height: PopqSpacing.xl),
            const Icon(
              Icons.storefront_rounded,
              size: 64,
              color: PopqPalette.forest,
            ),
            const SizedBox(height: PopqSpacing.lg),
            const Text(
              'POPQ SELLER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PopqPalette.coral,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              '내 스토어의 오늘을\n간편하게 운영하세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PopqSpacing.md),
            const Text(
              '판매자 계정과 소속 스토어 권한을 확인한 뒤 주문·상품·매출 기능을 제공합니다.',
              textAlign: TextAlign.center,
            ),
            if (widget.roleMismatch) ...[
              const SizedBox(height: PopqSpacing.lg),
              const Card(
                color: Color(0xFFFFE5DF),
                child: Padding(
                  padding: EdgeInsets.all(PopqSpacing.md),
                  child: Text(
                    '일반 고객 계정은 판매자 앱에서 사용할 수 없습니다. 판매자 계정으로 로그인해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            const SizedBox(height: PopqSpacing.xl),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('sign-in-email'),
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
                    key: const Key('sign-in-password'),
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '비밀번호'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: PopqSpacing.md),
                  FilledButton(
                    key: const Key('sign-in-submit'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(_busy ? '로그인 중...' : '로그인'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PopqSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  key: const Key('go-to-find-id'),
                  onPressed: _busy
                      ? null
                      : () => context.push(SellerRoutes.findId),
                  child: const Text('아이디 찾기'),
                ),
                const Text('|'),
                TextButton(
                  key: const Key('go-to-find-password'),
                  onPressed: _busy
                      ? null
                      : () => context.push(SellerRoutes.findPassword),
                  child: const Text('비밀번호 찾기'),
                ),
              ],
            ),
            TextButton(
              key: const Key('go-to-sign-up'),
              onPressed: _busy
                  ? null
                  : () => context.push(SellerRoutes.signUp),
              child: const Text('아직 계정이 없으신가요? 판매자 회원가입'),
            ),
            const SizedBox(height: PopqSpacing.md),
            const Divider(),
            const SizedBox(height: PopqSpacing.md),
             _ProviderButton(
              label: '판매자 Google 계정으로 계속하기',
               backgroundColor: Colors.white,
               foregroundColor: const Color(0xFF1F1F1F),
               borderColor: const Color(0xFFDADCE0),
              onPressed: widget.onGoogleSignIn == null || _busy
                  ? null
                  : _handleGoogleSignIn,),
            const SizedBox(height: PopqSpacing.sm),
             _ProviderButton(
                label: '판매자 Kakao 계정으로 계속하기',
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF191919),
                borderColor: const Color(0xFFFEE500),
            onPressed: widget.onKakaoSignIn == null || _busy
              ? null
              : _handleKakaoSignIn,
             ),
            const SizedBox(height: PopqSpacing.sm),
            _ProviderButton(
              label: '판매자 Naver 계정으로 계속하기',
              backgroundColor: const Color(0xFF03C75A),
              foregroundColor: Colors.white,
              borderColor: const Color(0xFF03C75A),
              onPressed: widget.onNaverSignIn == null || _busy
                  ? null
                  : _handleNaverSignIn,
            ),
            if (widget.onDevelopmentSignIn != null) ...[
              const SizedBox(height: PopqSpacing.lg),
              const Divider(),
              const SizedBox(height: PopqSpacing.md),
              FilledButton.icon(
                onPressed: _busy ? null : _developmentSignIn,
                icon: const Icon(Icons.science_outlined),
                label: Text(_busy ? '개발 로그인 중...' : '개발용 판매자로 로그인'),
              ),
              const SizedBox(height: PopqSpacing.sm),
              const Text(
                '개발 빌드에서만 보이며 고객 앱과 다른 SELLER 계정을 사용합니다.',
                textAlign: TextAlign.center,
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
            const SizedBox(height: PopqSpacing.lg),
            const Text(
              '소셜 로그인은 공급자 설정 완료 후 연결됩니다.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_busy || widget.onGoogleSignIn == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await widget.onGoogleSignIn!();
    } catch (error) {
      debugPrint('판매자 Google 로그인 오류: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Google 로그인에 실패했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleKakaoSignIn() async {
    if (_busy || widget.onKakaoSignIn == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await widget.onKakaoSignIn!();
    } catch (error) {
      debugPrint('판매자 Kakao 로그인 오류: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Kakao 로그인에 실패했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleNaverSignIn() async {
    if (_busy || widget.onNaverSignIn == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await widget.onNaverSignIn!();
    } catch (error) {
      debugPrint('판매자 Naver 로그인 오류: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Naver 로그인에 실패했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });


    try {
      await widget.onSignIn(_email.text.trim(), _password.text);
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
        _errorMessage = '로그인에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _developmentSignIn() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await widget.onDevelopmentSignIn!();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = '개발 로그인에 실패했습니다. 로컬 백엔드 상태를 확인해 주세요.';
      });
    }
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor:
        backgroundColor.withValues(alpha: 0.55),
        disabledForegroundColor:
        foregroundColor.withValues(alpha: 0.55),
        side: BorderSide(color: borderColor),
      ),
      child: Text(label),
    );
  }
}
