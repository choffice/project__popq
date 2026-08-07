import 'package:flutter/material.dart';
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
      _updatingIds.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PopqSpacing.md,
            PopqSpacing.md,
            PopqSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '사업장 공지',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (widget.canManage)
                FilledButton.icon(
                  key: const Key('add-announcement'),
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('공지 작성'),
                ),
            ],
          ),
        ),
        const SizedBox(height: PopqSpacing.sm),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(message: '사업장 공지사항을 불러오고 있어요.');
    }
    if (_error != null || _announcements == null) {
      return PopqErrorView(
        message: '공지사항을 불러오지 못했습니다.',
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('announcement-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.md),
        children: [
          if (_announcements!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  const PopqEmptyView(
                    icon: Icons.campaign_outlined,
                    title: '등록된 공지사항이 없어요.',
                    description: '사업장 운영 소식을 작성하고 게시 상태를 관리하세요.',
                  ),
                  if (widget.canManage) ...[
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
            )
          else
            for (final announcement in _announcements!) ...[
              _announcementCard(announcement),
              const SizedBox(height: PopqSpacing.sm),
            ],
          if (!widget.canManage)
            const Padding(
              padding: EdgeInsets.only(top: PopqSpacing.sm),
              child: Text(
                'STAFF는 공지사항을 조회할 수 있으며 작성·수정·게시 권한은 없습니다.',
                textAlign: TextAlign.center,
              ),
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
                Chip(
                  label: Text(_statusLabel(announcement.status)),
                  backgroundColor: _statusColor(announcement.status),
                ),
              ],
            ),
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
                    key: Key('edit-announcement-${announcement.announcementId}'),
                    onPressed: updating ? null : () => _edit(announcement),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
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
      final announcements = await widget.repository.findAll(storeId);
      if (!mounted ||
          requestSerial != _requestSerial ||
          widget.storeId != storeId) return;
      setState(() {
        _announcements = List.of(announcements);
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          requestSerial != _requestSerial ||
          widget.storeId != storeId) return;
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
      final saved = announcement == null
          ? await widget.repository.create(
              storeId,
              title: draft.title,
              content: draft.content,
              notifyInterestedCustomers: draft.notifyInterestedCustomers,
            )
          : await widget.repository.update(
              storeId,
              announcement,
              title: draft.title,
              content: draft.content,
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
        _announcements = announcements;
        _error = null;
      });
      _showMessage('${saved.title} 공지를 저장했습니다.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('공지사항을 저장하지 못했습니다.');
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
        _updatingIds.remove(announcement.announcementId);
      });
      _showMessage('${saved.title} 공지를 ${_statusLabel(status)} 상태로 변경했습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingIds.remove(announcement.announcementId));
      _showMessage('공지 게시 상태를 변경하지 못했습니다.');
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
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AnnouncementDraft {
  const _AnnouncementDraft({
    required this.title,
    required this.content,
    required this.notifyInterestedCustomers,
  });

  final String title;
  final String content;
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
                notifyInterestedCustomers: _notifyInterestedCustomers,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
