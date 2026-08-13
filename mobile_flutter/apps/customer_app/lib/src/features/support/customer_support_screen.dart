import 'dart:async';

import 'package:flutter/material.dart';

import 'customer_support_faq.dart';
import 'customer_support_repository.dart';

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({
    required this.repository,
    required this.onCreateInquiry,
    required this.onMyInquiries,
    super.key,
  });

  final CustomerSupportRepository repository;
  final VoidCallback onCreateInquiry;
  final VoidCallback onMyInquiries;

  @override
  State<CustomerSupportScreen> createState() {
    return _CustomerSupportScreenState();
  }
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchTimer;
  List<CustomerSupportFaq> _faqs = const [];
  bool _loading = true;
  String? _errorMessage;
  int? _expandedFaqId;

  @override
  void initState() {
    super.initState();
    _loadPopularFaqs();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
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

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _search(value),
    );
  }

  Future<void> _search(String keyword) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _expandedFaqId = null;
    });

    try {
      final faqs = keyword.trim().isEmpty
          ? await widget.repository.getPopularFaqs()
          : await widget.repository.getFaqs(keyword: keyword);

      if (!mounted) {
        return;
      }

      setState(() {
        _faqs = faqs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = '검색 결과를 불러오지 못했어요.';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchTimer?.cancel();
    _loadPopularFaqs();
  }

  void _toggleFaq(int supportFaqId) {
    setState(() {
      _expandedFaqId = _expandedFaqId == supportFaqId ? null : supportFaqId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('고객센터'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: widget.onMyInquiries,
            child: const Text('문의 내역'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPopularFaqs,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '궁금한 내용을 검색해 보세요',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          tooltip: '검색어 지우기',
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _searchController.text.trim().isEmpty ? '인기 질문' : '검색 결과',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _buildFaqContent(context),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '원하는 답변을 찾지 못하셨나요?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onCreateInquiry,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '1:1 문의하기',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqContent(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return _SupportMessageCard(
        icon: Icons.error_outline_rounded,
        message: _errorMessage!,
        buttonLabel: '다시 시도',
        onPressed: () => _search(_searchController.text),
      );
    }

    if (_faqs.isEmpty) {
      return const _SupportMessageCard(
        icon: Icons.search_off_rounded,
        message: '검색 결과가 없어요.',
      );
    }

    return Column(
      children: _faqs
          .map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqCard(
                faq: faq,
                expanded: _expandedFaqId == faq.supportFaqId,
                onTap: () => _toggleFaq(faq.supportFaqId),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.faq,
    required this.expanded,
    required this.onTap,
  });

  final CustomerSupportFaq faq;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    faq.answer,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportMessageCard extends StatelessWidget {
  const _SupportMessageCard({
    required this.icon,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(message),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onPressed, child: Text(buttonLabel!)),
          ],
        ],
      ),
    );
  }
}
