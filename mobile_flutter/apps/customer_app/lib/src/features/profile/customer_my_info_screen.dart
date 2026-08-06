import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';

class CustomerMyInfoScreen extends StatefulWidget {
  const CustomerMyInfoScreen({
    required this.repository,
    super.key,
  });

  final CustomerEngagementRepository repository;

  @override
  State<CustomerMyInfoScreen> createState() => _CustomerMyInfoScreenState();
}

class _CustomerMyInfoScreenState extends State<CustomerMyInfoScreen> {
  late Future<CustomerProfile> _profile;
  late Future<List<String>> _linkedSocialProviders;

  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingProfileImage = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.getProfile();
    _linkedSocialProviders = widget.repository.getLinkedSocialProviders();
  }

  Future<void> _reloadProfile() async {
    final nextProfile = widget.repository.getProfile();
    setState(() => _profile = nextProfile);
    await nextProfile;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      _showMessage('비밀번호가 변경됐어요.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('비밀번호를 변경하지 못했어요. ($error)');
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
                        title: const Text('이름'),
                        subtitle: Text(profile.name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: const Text('이메일'),
                        subtitle: Text(profile.email),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.call_outlined),
                        title: const Text('전화번호'),
                        subtitle: Text(profile.phone ?? '등록된 전화번호가 없어요'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editPhone(profile.phone),
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
                  '연동된 소셜 로그인',
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

                      final providers = socialSnapshot.data ?? const [];

                      if (providers.isEmpty) {
                        return const ListTile(
                          leading: Icon(Icons.link_off_rounded),
                          title: Text('연동된 소셜 계정이 없어요'),
                        );
                      }

                      return Column(
                        children: [
                          for (var index = 0;
                              index < providers.length;
                              index++) ...[
                            if (index > 0) const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.link_rounded),
                              title: Text(
                                _socialProviderLabel(providers[index]),
                              ),
                            ),
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

class _PhoneEditDialog extends StatefulWidget {
  const _PhoneEditDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_PhoneEditDialog> createState() => _PhoneEditDialogState();
}

class _PhoneEditDialogState extends State<_PhoneEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('전화번호 변경'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: '01012345678'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
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
