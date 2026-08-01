import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.onBackHome,
    this.onDevelopmentSignIn,
    this.returnResultOnSuccess = false,
    this.returnLocation,
    super.key,
  });

  final VoidCallback onBackHome;
  final Future<void> Function()? onDevelopmentSignIn;

  /*
   * true이면 로그인 성공 후 다른 경로로 이동하지 않고
   * 현재 로그인 화면을 닫으며 true를 이전 화면에 반환합니다.
   */
  final bool returnResultOnSuccess;

  /*
   * 라우터에서 직접 로그인 화면으로 진입했을 때
   * 로그인 성공 후 이동할 앱 내부 경로입니다.
   */
  final String? returnLocation;

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
          onPressed: _busy ? null : _closeSignIn,
          icon: const Icon(Icons.close_rounded),
          tooltip: '이전 화면으로 돌아가기',
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

  void _closeSignIn() {
    final navigator = Navigator.of(context);

    /*
     * 장바구니에서 전체 화면 모달로 열린 경우에는
     * GoRouter가 아니라 Navigator에서 직접 제거합니다.
     */
    if (navigator.canPop()) {
      navigator.pop(false);
      return;
    }

    widget.onBackHome();
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
       * 장바구니에서 전체 화면 모달로 로그인한 경우:
       * 로그인 화면 자체를 제거하면서 성공 결과를 반환합니다.
       *
       * Navigator.pop을 사용하므로 로그인 화면이
       * GoRouter의 뒤로가기 기록에 남지 않습니다.
       */
      if (widget.returnResultOnSuccess) {
        final navigator = Navigator.of(context);

        if (navigator.canPop()) {
          navigator.pop(true);
          return;
        }
      }

      /*
       * 마이페이지 등의 보호 경로에서 라우터를 통해
       * 로그인 화면으로 들어온 경우에는 기존 방식으로 이동합니다.
       */
      context.go(
        _safeReturnLocation(widget.returnLocation),
      );
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

  String _safeReturnLocation(String? locationValue) {
    if (locationValue == null ||
        locationValue.trim().isEmpty) {
      return '/home';
    }

    final location = locationValue.trim();
    final uri = Uri.tryParse(location);

    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !location.startsWith('/') ||
        location.startsWith('//') ||
        location.startsWith('/sign-in')) {
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