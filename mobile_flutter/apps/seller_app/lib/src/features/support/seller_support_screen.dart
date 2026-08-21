import 'dart:async';

import 'package:flutter/material.dart';

import 'seller_support_faq.dart';
import 'seller_support_repository.dart';

class SellerSupportScreen extends StatefulWidget {
  const SellerSupportScreen({
    required this.repository,
    required this.onCreateTicket,
    required this.onMyTickets,
    super.key,
  });

  final SellerSupportRepository repository;
  final VoidCallback onCreateTicket;
  final VoidCallback onMyTickets;

  @override
  State<SellerSupportScreen> createState() {
    return _SellerSupportScreenState();
  }
}

class _SellerSupportScreenState extends State<SellerSupportScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _faqPollingTimer;
  bool _faqPollingInProgress = false;

  List<SellerSupportFaq> _faqs = const [];

  bool _loading = true;
  String? _errorMessage;
  int? _expandedFaqId;

  @override
  void initState() {
    super.initState();
    _loadPopularFaqs();
    _startFaqPolling();
  }

  @override
  void dispose() {
    _faqPollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularFaqs() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final faqs = await widget.repository.getPopularFaqs();

      if (!mounted) {
        return;
      }

      setState(() {
        _faqs = faqs;
        _loading = false;
        _expandedFaqId = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = '자주 묻는 질문을 불러오지 못했어요.';
      });
    }
  }

  void _startFaqPolling() {
    _faqPollingTimer?.cancel();

    _faqPollingTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => unawaited(_refreshFaqsSilently()),
    );
  }

  Future<void> _refreshFaqsSilently() async {
    if (!mounted || _faqPollingInProgress) {
      return;
    }

    _faqPollingInProgress = true;

    try {
      final keyword = _searchController.text.trim();

      final faqs = keyword.isEmpty
          ? await widget.repository.getPopularFaqs()
          : await widget.repository.getFaqs(keyword: keyword);

      if (!mounted) {
        return;
      }

      setState(() {
        _faqs = faqs;
        _errorMessage = null;

        if (_expandedFaqId != null &&
            !faqs.any((faq) => faq.faqId == _expandedFaqId)) {
          _expandedFaqId = null;
        }
      });
    } catch (_) {
      // 자동 갱신 실패 시 기존 FAQ를 그대로 유지합니다.
    } finally {
      _faqPollingInProgress = false;
    }
  }

  Future<void> _searchFaqs() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final keyword = _searchController.text.trim();

      final faqs = keyword.isEmpty
          ? await widget.repository.getPopularFaqs()
          : await widget.repository.getFaqs(keyword: keyword);

      if (!mounted) {
        return;
      }

      setState(() {
        _faqs = faqs;
        _loading = false;
        _expandedFaqId = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'FAQ 검색 결과를 불러오지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객센터'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPopularFaqs,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                '무엇을 도와드릴까요?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '자주 묻는 질문을 확인하거나\nPOPQ 관리자에게 직접 문의할 수 있어요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SearchBar(
                controller: _searchController,
                hintText: '궁금한 내용을 검색해 보세요',
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _loadPopularFaqs();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
                onChanged: (_) {
                  setState(() {});
                },
                onSubmitted: (_) {
                  _searchFaqs();
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    _searchController.text.trim().isEmpty
                        ? '자주 묻는 질문'
                        : '검색 결과',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (_searchController.text.trim().isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _loadPopularFaqs();
                      },
                      child: const Text('전체 보기'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFaqContent(),
              const SizedBox(height: 24),
              _SupportActionCard(
                icon: Icons.edit_note_rounded,
                title: '1:1 문의하기',
                description: '문의 내용을 남기면 관리자가 확인 후 답변해 드려요.',
                onTap: widget.onCreateTicket,
              ),
              const SizedBox(height: 12),
              _SupportActionCard(
                icon: Icons.forum_outlined,
                title: '내 문의 내역',
                description: '문의 처리 상태와 관리자 답변을 확인할 수 있어요.',
                onTap: widget.onMyTickets,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return _SupportMessage(
        icon: Icons.error_outline_rounded,
        message: _errorMessage!,
        actionLabel: '다시 시도',
        onAction: _searchController.text.trim().isEmpty
            ? _loadPopularFaqs
            : _searchFaqs,
      );
    }

    if (_faqs.isEmpty) {
      return const _SupportMessage(
        icon: Icons.search_off_rounded,
        message: '검색 결과가 없어요.',
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < _faqs.length; index++) ...[
            _FaqTile(
              faq: _faqs[index],
              expanded: _expandedFaqId == _faqs[index].faqId,
              onTap: () {
                setState(() {
                  _expandedFaqId = _expandedFaqId == _faqs[index].faqId
                      ? null
                      : _faqs[index].faqId;
                });
              },
            ),
            if (index < _faqs.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SupportActionCard extends StatelessWidget {
  const _SupportActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    required this.expanded,
    required this.onTap,
  });

  final SellerSupportFaq faq;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    faq.question,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(30, 14, 8, 2),
                      child: Text(
                        faq.answer,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportMessage extends StatelessWidget {
  const _SupportMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
