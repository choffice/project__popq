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
            ? '移대찓?쇰? ?ㅽ뻾?섏? 紐삵뻽?듬땲??'
            : '媛ㅻ윭由ъ뿉???ъ쭊??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
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
      _showMessage('?꾨줈???ъ쭊??蹂寃쎈릱?댁슂.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('?꾨줈???ъ쭊??蹂寃쏀븯吏 紐삵뻽?댁슂. ($error)');
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
        title: '?대쫫 蹂寃?,
        initialValue: currentName,
        hintText: '?대쫫???낅젰?섏꽭??,
      ),
    );

    if (newName == null || !mounted) return;

    try {
      await widget.repository.updateName(newName);
      if (!mounted) return;
      await _reloadProfile();
      if (!mounted) return;
      _showMessage('?대쫫??蹂寃쎈릱?댁슂.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('?대쫫??蹂寃쏀븯吏 紐삵뻽?댁슂. ($error)');
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
      _showMessage('?꾪솕踰덊샇媛 蹂寃쎈릱?댁슂.');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('?꾪솕踰덊샇瑜?蹂寃쏀븯吏 紐삵뻽?댁슂. ($error)');
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
              '鍮꾨?踰덊샇媛 蹂寃쎈릺??紐⑤뱺 湲곌린?먯꽌 濡쒓렇?꾩썐?먯뼱?? ??鍮꾨?踰덊샇濡??ㅼ떆 濡쒓렇?명빐 二쇱꽭??',
            ),
          ),
        );
      context.go(CustomerRoutes.home);
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('鍮꾨?踰덊샇瑜?蹂寃쏀븯吏 紐삵뻽?댁슂. ($error)');
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
      _showMessage('?꾩옱 吏?먮릺吏 ?딅뒗 ?곕룞?댁뿉??');
      return;
    }

    setState(() => _linkingProvider = provider);
    try {
      await callback();
      if (!mounted) return;
      await _reloadLinkedSocialProviders();
      if (!mounted) return;
      _showMessage('${_socialProviderLabel(provider)} ?곕룞???꾨즺?먯뼱??');
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      _showMessage(failure.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('${_socialProviderLabel(provider)} ?곕룞???ㅽ뙣?덉뼱?? ($error)');
    } finally {
      if (mounted) {
        setState(() => _linkingProvider = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('???뺣낫')),
      body: FutureBuilder<CustomerProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '???뺣낫瑜?遺덈윭?ㅺ퀬 ?덉뼱??');
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '???뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?댁슂.',
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
                        title: const Text('?대쫫'),
                        subtitle: Text(profile.name),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editName(profile.name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: const Text('?대찓??(ID)'),
                        subtitle: Text(profile.email),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.call_outlined),
                        title: const Text('?꾪솕踰덊샇'),
                        subtitle: Text(
                          formatKoreanPhoneNumber(profile.phone) ??
                              '?깅줉???꾪솕踰덊샇媛 ?놁뼱??,
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
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('鍮꾨?踰덊샇 蹂寃?),
                    subtitle: const Text('濡쒓렇??鍮꾨?踰덊샇瑜?蹂寃쏀빐??),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changePassword,
                  ),
                ),
                const SizedBox(height: PopqSpacing.md),
                Text(
                  '?뚯뀥 濡쒓렇???곕룞',
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
                            trailing: const Text('?곕룞??),
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
                                    child: const Text('?곕룞?섍린'),
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
    'KAKAO' => '移댁뭅??,
    'NAVER' => '?ㅼ씠踰?,
    'FIREBASE' => 'Firebase',
    _ => provider,
  };
}

/// "010"?쇰줈 ?쒖옉?섎뒗 11?먮━ ?대???踰덊샇?몄? 寃?ы빀?덈떎.
/// 諛깆뿏?쒖쓽 `UpdatePhoneRequest` ?뺢퇋??`^010-?\d{4}-?\d{4}$`)怨??숈씪??洹쒖튃?낅땲??
bool isValidKoreanPhoneNumber(String digitsOnly) {
  return RegExp(r'^010\d{8}$').hasMatch(digitsOnly);
}

/// ?レ옄留??덈뒗 ?꾪솕踰덊샇(?? "01012345678")瑜?"010-1234-5678" ?뺥깭濡?蹂?섑빀?덈떎.
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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('痍⑥냼'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: const Text('???),
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
      setState(() => _errorText = '?꾪솕踰덊샇瑜??낅젰??二쇱꽭??');
      return;
    }

    if (!isValidKoreanPhoneNumber(digits)) {
      setState(
        () => _errorText = '?꾪솕踰덊샇瑜??ㅼ떆 ?뺤씤??二쇱꽭??',
      );
      return;
    }

    Navigator.of(context).pop(digits);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('?꾪솕踰덊샇 蹂寃?),
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
          child: const Text('痍⑥냼'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('???),
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
      setState(() => _errorText = '紐⑤뱺 ??ぉ???낅젰??二쇱꽭??');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorText = '??鍮꾨?踰덊샇媛 ?쒕줈 ?щ씪??');
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
      title: const Text('鍮꾨?踰덊샇 蹂寃?),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '?꾩옱 鍮꾨?踰덊샇'),
          ),
          const SizedBox(height: PopqSpacing.sm),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '??鍮꾨?踰덊샇',
              helperText: '?곷Ц, ?レ옄 ?ы븿 8???댁긽',
            ),
          ),
          const SizedBox(height: PopqSpacing.sm),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '??鍮꾨?踰덊샇 ?뺤씤'),
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
          child: const Text('痍⑥냼'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('蹂寃?),
        ),
      ],
    );
  }
}

