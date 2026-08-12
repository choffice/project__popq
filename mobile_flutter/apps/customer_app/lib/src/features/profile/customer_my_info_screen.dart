import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'customer_engagement_repository.dart';

const List<String> _linkableSocialProviders = ['GOOGLE', 'KAKAO', 'NAVER'];

class CustomerMyInfoScreen extends StatefulWidget {
  const CustomerMyInfoScreen({
    required this.repository,
    required this.onSignOut,
    this.onGoogleLink,
    this.onKakaoLink,
    this.onNaverLink,
    super.key,
  });

  final CustomerEngagementRepository repository;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onGoogleLink;
  final Future<void> Function()? onKakaoLink;
  final Future<void> Function()? onNaverLink;

  @override
  State<CustomerMyInfoScreen> createState() => _CustomerMyInfoScreenState();
}

class _CustomerMyInfoScreenState extends State<CustomerMyInfoScreen> {
  late Future<CustomerProfile> _profile;
  late Future<List<String>> _linkedSocialProviders;

  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingProfileImage = false;
  bool _savingEmblemVisibility = false;
  String? _linkingProvider;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.getProfile();
    _linkedSocialProviders = widget.repository.getLinkedSocialProviders();
  }

  Future<void> _reloadProfile() async {
    final nextProfile = widget.repository.getProfile();
    setState(() {
      _profile = nextProfile;
    });
    await nextProfile;
  }

  Future<void> _reloadLinkedSocialProviders() async {
    final nextProviders = widget.repository.getLinkedSocialProviders();
    setState(() {
      _linkedSocialProviders = nextProviders;
    });
    await nextProviders;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProfileImage() async {
    if (_uploadingProfileImage) return;

    final PopqImageSource? source = await showPopqImageSourceSheet(context);
    if (source == null || !mounted) return;

    final ImageSource pickerSource = source == PopqImageSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: pickerSource,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        pickerSource == ImageSource.camera
            ? '카메라를 실행하지 못했습니다.'
            : '갤러리에서 사진을 불러오지 못했습니다.',
      );
      return;
    }

    if (image == null || !mounted) return;

    setState(() => _uploadingProfileImage = true);
    try {
      await widget.repository.uploadProfileImage(image.path);

      if (!mounted) return;
      await _reloadProfile();

      if (!mounted) return;
      _showMessage('프로필 사진이 변경됐어요.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('프로필 사진을 변경하지 못했어요. ($error)');
    } finally {
      if (mounted) {
        setState(() => _uploadingProfileImage = false);
      }
    }
  }

  Future<void> _editName(String currentName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _TextEditDialog(
        title: '닉네임 변경',
        initialValue: currentName,
        hintText: '닉네임을 입력하세요',
      ),
    );

    if (newName == null || !mounted) return;

    try {
      await widget.repository.updateName(newName);
      if (!mounted) return;
      await _reloadProfile();
      if (!mounted) return;
      _showMessage('닉네임이 변경됐어요.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('닉네임을 변경하지 못했어요. ($error)');
    }
  }

  Future<void> _editPhone(String? currentPhone) async {
    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => _PhoneEditDialog(initialValue: currentPhone),
    );

    if (newPhone == null || !mounted) return;

    try {
      await widget.repository.updatePhone(newPhone);
      if (!mounted) return;
      await _reloadProfile();
      if (!mounted) return;
      _showMessage('전화번호가 변경됐어요.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('전화번호를 변경하지 못했어요. ($error)');
    }
  }

  Future<void> _updateEmblemVisibility(
    CustomerProfile profile,
    bool emblemVisible,
  ) async {
    if (_savingEmblemVisibility) return;

    setState(() => _savingEmblemVisibility = true);
    try {
      final saved = await widget.repository.updateEmblemVisibility(
        emblemVisible,
      );
      if (!mounted) return;
      setState(() {
        _profile = Future<CustomerProfile>.value(
          profile.copyWith(emblemVisible: saved),
        );
      });
      _showMessage(saved ? '엠블럼을 표시합니다.' : '엠블럼을 숨겼습니다.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('엠블럼 표시 설정을 변경하지 못했어요. ($error)');
    } finally {
      if (mounted) {
        setState(() => _savingEmblemVisibility = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<_PasswordChangeResult>(
      context: context,
      builder: (context) => const _PasswordChangeDialog(),
    );

    if (result == null || !mounted) return;

    try {
      await widget.repository.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      if (!mounted) return;

      await widget.onSignOut();
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '비밀번호가 변경되어 모든 기기에서 로그아웃됐어요. 새 비밀번호로 다시 로그인해 주세요.',
            ),
          ),
        );
      context.go(CustomerRoutes.home);
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('비밀번호를 변경하지 못했어요. ($error)');
    }
  }

  Future<void> _linkProvider(String provider) async {
    if (_linkingProvider != null) return;

    final callback = switch (provider) {
      'GOOGLE' => widget.onGoogleLink,
      'KAKAO' => widget.onKakaoLink,
      'NAVER' => widget.onNaverLink,
      _ => null,
    };

    if (callback == null) {
      _showMessage('현재 지원되지 않는 연동이에요.');
      return;
    }

    setState(() => _linkingProvider = provider);
    try {
      await callback();
      if (!mounted) return;
      await _reloadLinkedSocialProviders();
      if (!mounted) return;
      _showMessage('${_socialProviderLabel(provider)} 연동이 완료됐어요.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('${_socialProviderLabel(provider)} 연동에 실패했어요. ($error)');
    } finally {
      if (mounted) {
        setState(() => _linkingProvider = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: FutureBuilder<CustomerProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '내 정보를 불러오고 있어요.');
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '내 정보를 불러오지 못했어요.',
              onRetry: _reloadProfile,
            );
          }

          final profile = snapshot.requireData;

          return RefreshIndicator(
            onRefresh: _reloadProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(PopqSpacing.lg),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: profile.profileImageUrl != null
                            ? NetworkImage(profile.profileImageUrl!)
                            : null,
                        child: profile.profileImageUrl == null
                            ? const Icon(Icons.person_rounded, size: 48)
                            : null,
                      ),
                      if (_uploadingProfileImage)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _editProfileImage,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.photo_camera_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PopqSpacing.lg),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('닉네임'),
                        subtitle: Text(profile.name),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editName(profile.name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: const Text('이메일 (ID)'),
                        subtitle: Text(profile.email),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.call_outlined),
                        title: const Text('전화번호'),
                        subtitle: Text(
                          formatKoreanPhoneNumber(profile.phone) ??
                              '등록된 전화번호가 없어요',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editPhone(profile.phone),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PopqSpacing.md),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: profile.activitySummary.badgeAssetPath == null
                            ? const Icon(Icons.workspace_premium_outlined)
                            : Image.asset(
                                profile.activitySummary.badgeAssetPath!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                semanticLabel:
                                    profile.activitySummary.badgeLabel,
                              ),
                        title: Text(profile.activitySummary.badgeLabel),
                        subtitle: const Text('내가 달성한 엠블럼'),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.visibility_outlined),
                        title: const Text('엠블럼 표시'),
                        subtitle: Text(
                          profile.emblemVisible
                              ? '프로필과 리뷰 등에 엠블럼을 표시해요.'
                              : '다른 사람에게 엠블럼을 표시하지 않아요.',
                        ),
                        value: profile.emblemVisible,
                        thumbIcon: const WidgetStatePropertyAll(
                          Icon(Icons.circle, size: 0),
                        ),
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.white,
                        ),
                        trackColor: WidgetStateProperty.resolveWith(
                          (states) {
                            if (states.contains(WidgetState.selected)) {
                              return Theme.of(context).colorScheme.primary;
                            }
                            return Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38);
                          },
                        ),
                        trackOutlineColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.transparent
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.64),
                        ),
                        onChanged: _savingEmblemVisibility
                            ? null
                            : (value) => _updateEmblemVisibility(
                                  profile,
                                  value,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PopqSpacing.md),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('비밀번호 변경'),
                    subtitle: const Text('로그인 비밀번호를 변경해요'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changePassword,
                  ),
                ),
                const SizedBox(height: PopqSpacing.md),
                Text(
                  '소셜 로그인 연동',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: PopqSpacing.sm),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: FutureBuilder<List<String>>(
                    future: _linkedSocialProviders,
                    builder: (context, socialSnapshot) {
                      if (socialSnapshot.connectionState !=
                          ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(PopqSpacing.md),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }

                      final linked = socialSnapshot.data ?? const [];
                      final linkable = _linkableSocialProviders
                          .where((provider) => !linked.contains(provider))
                          .toList();

                      final rows = <Widget>[
                        for (final provider in linked)
                          ListTile(
                            leading: const Icon(Icons.link_rounded),
                            title: Text(_socialProviderLabel(provider)),
                            trailing: const Text('연동됨'),
                          ),
                        for (final provider in linkable)
                          ListTile(
                            leading: const Icon(Icons.link_off_rounded),
                            title: Text(_socialProviderLabel(provider)),
                            trailing: _linkingProvider == provider
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: () => _linkProvider(provider),
                                    child: const Text('연동하기'),
                                  ),
                          ),
                      ];

                      return Column(
                        children: [
                          for (var index = 0; index < rows.length; index++) ...[
                            if (index > 0) const Divider(height: 1),
                            rows[index],
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _socialProviderLabel(String provider) {
  return switch (provider) {
    'GOOGLE' => 'Google',
    'KAKAO' => '카카오',
    'NAVER' => '네이버',
    'FIREBASE' => 'Firebase',
    _ => provider,
  };
}

/// "010"으로 시작하는 11자리 휴대폰 번호인지 검사합니다.
/// 백엔드의 `UpdatePhoneRequest` 정규식(`^010-?\d{4}-?\d{4}$`)과 동일한 규칙입니다.
bool isValidKoreanPhoneNumber(String digitsOnly) {
  return RegExp(r'^010\d{8}$').hasMatch(digitsOnly);
}

/// 숫자만 있는 전화번호(예: "01012345678")를 "010-1234-5678" 형태로 변환합니다.
String? formatKoreanPhoneNumber(String? raw) {
  final digits = raw?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  if (digits.isEmpty) return null;

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 7) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _KoreanPhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = formatKoreanPhoneNumber(limited) ?? '';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.title,
    required this.hintText,
    this.initialValue,
  });

  final String title;
  final String hintText;
  final String? initialValue;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  static final _nicknamePattern = RegExp(
    r'^[A-Za-z0-9 \u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7A3\u3131-\u318E]+$',
    unicode: true,
  );

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLength: 7,
        decoration: InputDecoration(
          hintText: widget.hintText,
          helperText: '7자 이하 · 한글/영문/숫자/일본어/한자/공백',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) {
              setState(() => _errorText = '닉네임을 입력해 주세요.');
              return;
            }
            if (value.length > 7) {
              setState(() => _errorText = '닉네임은 7자 이하로 입력해 주세요.');
              return;
            }
            if (!_nicknamePattern.hasMatch(value)) {
              setState(() => _errorText = '사용할 수 없는 문자가 포함되어 있어요.');
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _PhoneEditDialog extends StatefulWidget {
  const _PhoneEditDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_PhoneEditDialog> createState() => _PhoneEditDialogState();
}

class _PhoneEditDialogState extends State<_PhoneEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: formatKoreanPhoneNumber(widget.initialValue) ?? '',
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      setState(() => _errorText = '전화번호를 입력해 주세요.');
      return;
    }

    if (!isValidKoreanPhoneNumber(digits)) {
      setState(
        () => _errorText = '전화번호를 다시 확인해 주세요.',
      );
      return;
    }

    Navigator.of(context).pop(digits);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('전화번호 변경'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [_KoreanPhoneNumberInputFormatter()],
        decoration: InputDecoration(
          hintText: '010-0000-0000',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _PasswordChangeResult {
  const _PasswordChangeResult({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      setState(() => _errorText = '모든 항목을 입력해 주세요.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorText = '새 비밀번호가 서로 달라요.');
      return;
    }

    Navigator.of(context).pop(
      _PasswordChangeResult(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('비밀번호 변경'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '현재 비밀번호'),
          ),
          const SizedBox(height: PopqSpacing.sm),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '새 비밀번호',
              helperText: '영문, 숫자 포함 8자 이상',
            ),
          ),
          const SizedBox(height: PopqSpacing.sm),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('변경'),
        ),
      ],
    );
  }
}
