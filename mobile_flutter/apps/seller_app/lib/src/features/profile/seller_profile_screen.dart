import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../auth/seller_identity_repository.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    required this.identityRepository,
    super.key,
  });

  final SellerIdentityRepository identityRepository;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late Future<SellerIdentity> _identity;

  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingProfileImage = false;

  @override
  void initState() {
    super.initState();
    _identity = widget.identityRepository.getCurrent();
  }

  Future<void> _reload() async {
    final nextIdentity = widget.identityRepository.getCurrent();
    setState(() {
      _identity = nextIdentity;
    });
    await nextIdentity;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pickerSource == ImageSource.camera
                ? '카메라를 실행하지 못했습니다.'
                : '갤러리에서 사진을 불러오지 못했습니다.',
          ),
        ),
      );
      return;
    }

    if (image == null || !mounted) return;

    setState(() => _uploadingProfileImage = true);
    try {
      await widget.identityRepository.uploadProfileImage(image.path);

      if (!mounted) return;
      await _reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 변경됐어요.')),
      );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 사진을 변경하지 못했어요. ($error)')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingProfileImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 프로필')),
      body: FutureBuilder<SellerIdentity>(
        future: _identity,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(
              message: '내 프로필을 불러오고 있어요.',
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '내 프로필을 불러오지 못했어요.',
              onRetry: _reload,
            );
          }

          final identity = snapshot.requireData;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(PopqSpacing.lg),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: identity.profileImageUrl != null
                            ? NetworkImage(identity.profileImageUrl!)
                            : null,
                        child: identity.profileImageUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 48,
                              )
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
                        subtitle: Text(identity.name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: const Text('이메일'),
                        subtitle: Text(identity.email),
                      ),
                    ],
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
