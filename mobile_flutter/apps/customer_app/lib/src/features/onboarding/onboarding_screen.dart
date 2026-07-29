import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../permissions/customer_permission_gateway.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.controller,
    required this.permissionGateway,
    super.key,
  });

  final OnboardingController controller;
  final CustomerPermissionGateway permissionGateway;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  var _page = 0;
  var _busy = false;
  String? _statusMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('건너뛰기'),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() {
                    _page = value;
                    _statusMessage = null;
                  }),
                  children: const [
                    _OnboardingPage(
                      icon: Icons.storefront_rounded,
                      eyebrow: 'WELCOME TO POPQ',
                      title: '좋아할 만한 곳을\n가볍게 발견하세요.',
                      description: '동네 매장부터 팝업과 행사까지, 취향에 맞는 경험을 한곳에서 찾습니다.',
                    ),
                    _OnboardingPage(
                      icon: Icons.near_me_rounded,
                      eyebrow: 'NEARBY',
                      title: '가까운 순서로\n먼저 보여드릴게요.',
                      description: '위치는 주변 매장 검색에만 사용하며 언제든 기기 설정에서 바꿀 수 있습니다.',
                    ),
                    _OnboardingPage(
                      icon: Icons.notifications_active_rounded,
                      eyebrow: 'STAY IN THE LOOP',
                      title: '주문과 관심 매장 소식을\n놓치지 마세요.',
                      description: '알림 허용 여부와 관계없이 POPQ의 모든 기본 기능을 사용할 수 있습니다.',
                    ),
                  ],
                ),
              ),
              if (_statusMessage != null) ...[
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: PopqSpacing.sm),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final selected = index == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? PopqPalette.forest
                          : PopqPalette.forest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: PopqSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _next,
                  child: Text(_buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _buttonLabel {
    return switch (_page) {
      0 => '시작하기',
      1 => '위치 허용하고 계속',
      _ => '알림 허용하고 완료',
    };
  }

  Future<void> _next() async {
    if (_page == 0) {
      await _moveTo(1);
      return;
    }
    setState(() => _busy = true);
    if (_page == 1) {
      final result = await widget.permissionGateway.requestLocation();
      if (!mounted) return;
      setState(() {
        _statusMessage = _permissionMessage(result.decision, '위치');
        _busy = false;
      });
      await _moveTo(2);
      return;
    }
    final decision = await widget.permissionGateway.requestNotifications();
    if (!mounted) return;
    setState(() {
      _statusMessage = _permissionMessage(decision, '알림');
      _busy = false;
    });
    await _finish();
  }

  Future<void> _moveTo(int page) {
    return _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    await widget.controller.complete();
  }

  String _permissionMessage(PermissionDecision decision, String label) {
    return switch (decision) {
      PermissionDecision.granted => '$label 권한이 허용되었습니다.',
      PermissionDecision.denied => '$label 권한은 나중에 다시 허용할 수 있어요.',
      PermissionDecision.permanentlyDenied =>
        '$label 권한이 차단되어 있습니다. 기기 설정에서 변경할 수 있어요.',
      PermissionDecision.serviceDisabled => '기기의 위치 서비스가 꺼져 있습니다.',
    };
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            color: PopqPalette.lime,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 56, color: PopqPalette.forest),
        ),
        const SizedBox(height: PopqSpacing.xl),
        Text(
          eyebrow,
          style: const TextStyle(
            color: PopqPalette.coral,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: PopqSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: PopqSpacing.md),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
