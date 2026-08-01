import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.onBackHome,
    this.onDevelopmentSignIn,
    super.key,
  });

  final VoidCallback onBackHome;
  final Future<void> Function()? onDevelopmentSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  var _busy = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _busy ? null : widget.onBackHome,
          icon: const Icon(Icons.close_rounded),
          tooltip: '홈으로 돌아가기',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: [
            const SizedBox(height: PopqSpacing.xl),
            const Text(
              'MEMBER BENEFITS',
              style: TextStyle(
                color: PopqPalette.coral,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              '로그인하고\nPOPQ를 이어서 즐겨보세요.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PopqSpacing.md),
            Text(
              '관심 스토어, 주문 내역, 리뷰를 여러 기기에서 안전하게 이어볼 수 있어요.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: PopqSpacing.xl),
            const _ProviderButton(
              label: 'Google로 계속하기',
            ),
            const SizedBox(height: PopqSpacing.sm),
            const _ProviderButton(
              label: 'Kakao로 계속하기',
            ),
            const SizedBox(height: PopqSpacing.sm),
            const _ProviderButton(
              label: 'Naver로 계속하기',
            ),
            if (widget.onDevelopmentSignIn != null) ...[
              const SizedBox(height: PopqSpacing.lg),
              const Divider(),
              const SizedBox(height: PopqSpacing.md),
              FilledButton.icon(
                onPressed: _busy ? null : _developmentSignIn,
                icon: const Icon(Icons.science_outlined),
                label: Text(
                  _busy
                      ? '개발 로그인 중...'
                      : '개발용 고객으로 로그인',
                ),
              ),
              const SizedBox(height: PopqSpacing.sm),
              const Text(
                '개발 빌드에서만 보이며 로컬 백엔드의 dev 인증을 사용합니다.',
                textAlign: TextAlign.center,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: PopqSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PopqPalette.coral,
                ),
              ),
            ],
            const SizedBox(height: PopqSpacing.lg),
            const Text(
              '운영 소셜 공급자와 토큰 교환은 공급자 확정 후 연결합니다.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _developmentSignIn() async {
    if (_busy || widget.onDevelopmentSignIn == null) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await widget.onDevelopmentSignIn!();

      if (!mounted) {
        return;
      }

      /*
       * 비로그인 상태에서 결제·주문·마이페이지 등에 접근하면
       * 라우터가 로그인 주소에 from 쿼리를 붙입니다.
       *
       * 예:
       * /sign-in?from=%2Fcheckout
       *
       * 로그인 성공 후 해당 주소로 직접 이동하여
       * 로그인 화면을 내비게이션 스택에 남기지 않습니다.
       */
      final from =
      GoRouterState.of(context).uri.queryParameters['from'];

      context.go(_safeReturnLocation(from));
    } catch (error, stackTrace) {
      debugPrint('개발 로그인 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _errorMessage = '로그인 실패: $error';
      });
    }
  }

  String _safeReturnLocation(String? from) {
    if (from == null || from.trim().isEmpty) {
      return '/home';
    }

    final location = from.trim();
    final uri = Uri.tryParse(location);

    /*
     * 외부 URL이나 잘못된 주소로 이동하지 않도록
     * 앱 내부 절대 경로만 허용합니다.
     */
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !location.startsWith('/') ||
        location.startsWith('//') ||
        location == '/sign-in') {
      return '/home';
    }

    return location;
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
      child: Text(label),
    );
  }
}