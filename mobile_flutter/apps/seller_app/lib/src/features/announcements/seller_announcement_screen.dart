import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'seller_announcement_repository.dart';

class SellerAnnouncementScreen extends StatefulWidget {
  const SellerAnnouncementScreen({
    required this.storeId,
    required this.canManage,
    required this.repository,
    super.key,
  });

  final int storeId;
  final bool canManage;
  final SellerAnnouncementRepository repository;

  @override
  State<SellerAnnouncementScreen> createState() =>
      _SellerAnnouncementScreenState();
}

class _SellerAnnouncementScreenState extends State<SellerAnnouncementScreen> {
  static const Duration _loadTimeout = Duration(seconds: 15);

  List<SellerAnnouncement>? _announcements;
  Object? _error;
  var _loading = true;
  final _updatingIds = <int>{};
  var _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SellerAnnouncementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId) {
      _announcements = null;
      _error = null;
      _loading = true;
      _updatingIds.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildHeader(context),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(message: '사업장 공지사항을 불러오고 있어요.');
    }
    if (_error != null || _announcements == null) {
      return PopqErrorView(message: '공지사항을 불러오지 못했습니다.', onRetry: _load);
    }
    if (_announcements!.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PopqEmptyView(
                icon: Icons.campaign_outlined,
                title: '등록된 공지사항이 없어요.',
                description: '사업장 운영 소식을 작성하고 게시 상태를 관리하세요.',
              ),
              if (widget.canManage) ...<Widget>[
                const SizedBox(height: PopqSpacing.md),
                FilledButton.icon(
                  key: const Key('add-first-announcement'),
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('첫 공지 작성'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (widget.canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              0,
              PopqSpacing.md,
              PopqSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('add-another-announcement'),
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('새 공지 작성'),
              ),
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              key: const Key('announcement-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PopqSpacing.md,
                0,
                PopqSpacing.md,
                PopqSpacing.md,
              ),
              itemCount: _announcements!.length + (widget.canManage ? 0 : 1),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PopqSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                if (index == _announcements!.length) {
                  return const Padding(
                    padding: EdgeInsets.only(top: PopqSpacing.sm),
                    child: Text(
                      'STAFF는 공지사항을 조회할 수 있으며 '
                      '작성·수정·게시 권한은 없습니다.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return _announcementCard(_announcements![index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PopqSpacing.md,
        PopqSpacing.md,
        PopqSpacing.md,
        PopqSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '사업장 공지',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (widget.canManage && (_announcements?.isNotEmpty ?? false))
            FilledButton.icon(
              key: const Key('add-announcement'),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('공지 작성'),
            ),
        ],
      ),
    );
  }

  Widget _announcementCard(SellerAnnouncement announcement) {
    final updating = _updatingIds.contains(announcement.announcementId);
    return Card(
      key: Key('announcement-${announcement.announcementId}'),
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (announcement.pinned) ...<Widget>[
                  const _PinnedBadge(),
                  const SizedBox(width: PopqSpacing.xs),
                ],
                Chip(
                  label: Text(_statusLabel(announcement.status)),
                  backgroundColor: _statusColor(announcement.status),
                ),
              ],
            ),

            if (announcement.imageUrl != null &&
                announcement.imageUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: PopqSpacing.sm),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  announcement.imageUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return Container(
                          height: 100,
                          alignment: Alignment.center,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                ),
              ),
            ],

            const SizedBox(height: PopqSpacing.xs),

            Text(announcement.content),
            if (announcement.publishedAt != null) ...[
              const SizedBox(height: PopqSpacing.xs),
              Text(
                '게시 ${_dateLabel(announcement.publishedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (widget.canManage) ...[
              const Divider(),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    key: Key(
                      'edit-announcement-${announcement.announcementId}',
                    ),
                    onPressed: updating ? null : () => _edit(announcement),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
                  ),
                  if (announcement.status == 'PUBLISHED')
                    TextButton.icon(
                      key: Key(
                        'pin-announcement-${announcement.announcementId}',
                      ),
                      onPressed: updating
                          ? null
                          : () =>
                                _changePin(announcement, !announcement.pinned),
                      icon: Icon(
                        announcement.pinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                      ),
                      label: Text(announcement.pinned ? '고정 해제' : '고정'),
                    ),
                  TextButton.icon(
                    key: Key(
                      'toggle-announcement-${announcement.announcementId}',
                    ),
                    onPressed: updating
                        ? null
                        : () => _changeStatus(
                            announcement,
                            announcement.status == 'PUBLISHED'
                                ? 'HIDDEN'
                                : 'PUBLISHED',
                          ),
                    icon: Icon(
                      announcement.status == 'PUBLISHED'
                          ? Icons.visibility_off_outlined
                          : Icons.publish_outlined,
                    ),
                    label: Text(
                      announcement.status == 'PUBLISHED' ? '숨김' : '게시',
                    ),
                  ),
                  TextButton.icon(
                    key: Key(
                      'delete-announcement-${announcement.announcementId}',
                    ),
                    onPressed: updating
                        ? null
                        : () => _deleteAnnouncement(announcement),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('삭제'),
                  ),
                ],
              ),
            ],
            if (updating) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final storeId = widget.storeId;
    final requestSerial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final announcements = await widget.repository
          .findAll(storeId)
          .timeout(_loadTimeout);
      if (!mounted ||
          requestSerial != _requestSerial ||
          widget.storeId != storeId)
        return;
      setState(() {
        _announcements = List.of(announcements);
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          requestSerial != _requestSerial ||
          widget.storeId != storeId)
        return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _edit([SellerAnnouncement? announcement]) async {
    final storeId = widget.storeId;
    final draft = await showDialog<_AnnouncementDraft>(
      context: context,
      builder: (_) => _AnnouncementEditor(announcement: announcement),
    );
    if (draft == null) return;
    try {
      String? imageUrl = draft.removeImage ? null : draft.imageUrl;

      final Uint8List? imageBytes = draft.imageBytes;
      final String? imageFileName = draft.imageFileName;
      final String? imageFilePath = draft.imageFilePath;
      final bool hasNewImageSelection =
          imageBytes != null || imageFileName != null;

      if (hasNewImageSelection &&
          (imageBytes == null ||
              imageBytes.isEmpty ||
              imageFileName == null ||
              imageFileName.trim().isEmpty)) {
        throw StateError('선택한 공지 이미지 데이터를 읽지 못했습니다.');
      }

      if (kIsWeb) {
        if (imageBytes != null &&
            imageBytes.isNotEmpty &&
            imageFileName != null &&
            imageFileName.trim().isNotEmpty) {
          imageUrl = await widget.repository.uploadAnnouncementImageBytes(
            imageBytes,
            fileName: imageFileName,
          );
        }
      } else if (imageFilePath != null && imageFilePath.trim().isNotEmpty) {
        imageUrl = await widget.repository.uploadAnnouncementImage(
          imageFilePath,
        );
      }

      final saved = announcement == null
          ? await widget.repository.create(
              storeId,
              title: draft.title,
              content: draft.content,
              imageUrl: imageUrl,
              notifyInterestedCustomers: draft.notifyInterestedCustomers,
            )
          : await widget.repository.update(
              storeId,
              announcement,
              title: draft.title,
              content: draft.content,
              imageUrl: imageUrl,
              notifyInterestedCustomers: draft.notifyInterestedCustomers,
            );
      if (!mounted || widget.storeId != storeId) return;
      setState(() {
        final announcements = _announcements ?? <SellerAnnouncement>[];
        final index = announcements.indexWhere(
          (item) => item.announcementId == saved.announcementId,
        );
        if (index < 0) {
          announcements.insert(0, saved);
        } else {
          announcements[index] = saved;
        }
        announcements.sort(_compareAnnouncements);
        _announcements = announcements;
        _error = null;
      });
      _showMessage('${saved.title} 공지를 저장했습니다.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('공지사항을 저장하지 못했습니다.');
    }
  }

  Future<void> _deleteAnnouncement(
    SellerAnnouncement announcement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('공지를 삭제할까요?'),
          content: Text(
            '「${announcement.title}」 공지를 삭제합니다.\n'
            '삭제한 공지는 복구할 수 없습니다.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _updatingIds.add(announcement.announcementId));

    try {
      await widget.repository.delete(
        widget.storeId,
        announcement,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _announcements?.removeWhere(
          (item) => item.announcementId == announcement.announcementId,
        );
        _updatingIds.remove(announcement.announcementId);
      });

      _showMessage('${announcement.title} 공지를 삭제했습니다.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _updatingIds.remove(announcement.announcementId));
      _showMessage('공지사항을 삭제하지 못했습니다.');
    }
  }

  Future<void> _changeStatus(
    SellerAnnouncement announcement,
    String status,
  ) async {
    setState(() => _updatingIds.add(announcement.announcementId));
    try {
      final saved = await widget.repository.changeStatus(
        widget.storeId,
        announcement,
        status,
      );
      if (!mounted) return;
      setState(() {
        final index = _announcements!.indexWhere(
          (item) => item.announcementId == saved.announcementId,
        );
        if (index >= 0) _announcements![index] = saved;
        _announcements!.sort(_compareAnnouncements);
        _updatingIds.remove(announcement.announcementId);
      });
      _showMessage('${saved.title} 공지를 ${_statusLabel(status)} 상태로 변경했습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingIds.remove(announcement.announcementId));
      _showMessage('공지 게시 상태를 변경하지 못했습니다.');
    }
  }

  Future<void> _changePin(SellerAnnouncement announcement, bool pinned) async {
    setState(() => _updatingIds.add(announcement.announcementId));
    try {
      final saved = await widget.repository.changePin(
        widget.storeId,
        announcement,
        pinned,
      );
      if (!mounted) return;
      setState(() {
        final index = _announcements!.indexWhere(
          (item) => item.announcementId == saved.announcementId,
        );
        if (index >= 0) _announcements![index] = saved;
        _announcements!.sort(_compareAnnouncements);
        _updatingIds.remove(announcement.announcementId);
      });
      _showMessage(
        pinned ? '${saved.title} 공지를 상단에 고정했습니다.' : '공지 고정을 해제했습니다.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingIds.remove(announcement.announcementId));
      if (error is ApiRequestFailure &&
          error.code == 'ANNOUNCEMENT_PIN_LIMIT_EXCEEDED') {
        _showMessage('고정 공지는 최대 3개까지 설정할 수 있습니다.');
        return;
      }
      if (error is ApiRequestFailure &&
          error.code == 'ANNOUNCEMENT_PIN_REQUIRES_PUBLISHED') {
        _showMessage('게시 중인 공지만 고정할 수 있습니다.');
        return;
      }
      _showMessage('공지 고정 상태를 변경하지 못했습니다.');
    }
  }

  String _statusLabel(String status) => switch (status) {
    'PUBLISHED' => '게시 중',
    'HIDDEN' => '숨김',
    _ => '작성 중',
  };

  Color _statusColor(String status) => switch (status) {
    'PUBLISHED' => const Color(0xFFD7F0E3),
    'HIDDEN' => const Color(0xFFE7E4EA),
    _ => const Color(0xFFFFE3C2),
  };

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showTopSnackBar(SnackBar(content: Text(message)));
  }
}

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '고정',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

int _compareAnnouncements(SellerAnnouncement left, SellerAnnouncement right) {
  if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
  if (left.pinned) {
    final publishedOrder = (right.publishedAt ?? right.createdAt).compareTo(
      left.publishedAt ?? left.createdAt,
    );
    if (publishedOrder != 0) return publishedOrder;
  }
  final createdOrder = right.createdAt.compareTo(left.createdAt);
  if (createdOrder != 0) return createdOrder;
  return right.announcementId.compareTo(left.announcementId);
}

class _AnnouncementDraft {
  const _AnnouncementDraft({
    required this.title,
    required this.content,
    required this.notifyInterestedCustomers,
    this.imageUrl,
    this.imageBytes,
    this.imageFileName,
    this.imageFilePath,
    this.removeImage = false,
  });

  final String title;
  final String content;

  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final String? imageFilePath;
  final bool removeImage;

  final bool notifyInterestedCustomers;
}

class _AnnouncementEditor extends StatefulWidget {
  const _AnnouncementEditor({required this.announcement});

  final SellerAnnouncement? announcement;

  @override
  State<_AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<_AnnouncementEditor> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool _notifyInterestedCustomers = false;

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.announcement?.title);
    _content = TextEditingController(text: widget.announcement?.content);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.announcement == null ? '공지 작성' : '공지 수정'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('announcement-title'),
                controller: _title,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: PopqSpacing.sm),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImagePreview(),
              ),

              const SizedBox(height: PopqSpacing.sm),

              Wrap(
                spacing: PopqSpacing.sm,
                runSpacing: PopqSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('사진 촬영'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('앨범 선택'),
                  ),
                  if (_pickedImage != null ||
                      (!_removeImage &&
                          (widget.announcement?.imageUrl?.trim().isNotEmpty ??
                              false)))
                    TextButton.icon(
                      onPressed: _clearImage,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('사진 삭제'),
                    ),
                ],
              ),

              const SizedBox(height: PopqSpacing.sm),
              TextField(
                key: const Key('announcement-content'),
                controller: _content,
                maxLength: 2000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: '내용'),
              ),
              CheckboxListTile(
                key: const Key('notify-interested-customers'),
                contentPadding: EdgeInsets.zero,
                value: _notifyInterestedCustomers,
                onChanged: (value) {
                  setState(() => _notifyInterestedCustomers = value ?? false);
                },
                title: const Text('찜한 고객에게 알림 보내기'),
                subtitle: const Text('저장과 동시에 공지를 게시하고 고객에게 알려요.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-announcement'),
          onPressed: () {
            final title = _title.text.trim();
            final content = _content.text.trim();
            if (title.isEmpty || content.isEmpty) return;
            Navigator.pop(
              context,
              _AnnouncementDraft(
                title: title,
                content: content,
                imageUrl: _removeImage ? null : widget.announcement?.imageUrl,
                imageBytes: _pickedImageBytes,
                imageFileName: _pickedImage?.name,
                imageFilePath: _pickedImage?.path,
                removeImage: _removeImage,
                notifyInterestedCustomers: _notifyInterestedCustomers,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _pickedImage = picked;
      _pickedImageBytes = bytes;
      _removeImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
      _removeImage = true;
    });
  }

  Widget _buildImagePreview() {
    if (_pickedImageBytes != null) {
      return Image.memory(
        _pickedImageBytes!,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      );
    }

    final existingUrl = widget.announcement?.imageUrl;

    if (!_removeImage && existingUrl != null && existingUrl.trim().isNotEmpty) {
      return Image.network(
        existingUrl,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return _emptyImagePreview();
            },
      );
    }

    return _emptyImagePreview();
  }

  Widget _emptyImagePreview() {
    return Container(
      width: double.infinity,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 40),
          SizedBox(height: 6),
          Text('첨부된 사진이 없습니다.'),
        ],
      ),
    );
  }
}
