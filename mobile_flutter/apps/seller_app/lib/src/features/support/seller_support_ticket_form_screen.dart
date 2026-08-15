import 'package:flutter/material.dart';

import 'seller_support_repository.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

class SellerSupportTicketFormScreen extends StatefulWidget {
  const SellerSupportTicketFormScreen({
    required this.repository,
    required this.sellerEmail,
    required this.onCreated,
    super.key,
  });

  final SellerSupportRepository repository;
  final String sellerEmail;
  final ValueChanged<SellerSupportTicketDetail> onCreated;

  @override
  State<SellerSupportTicketFormScreen> createState() {
    return _SellerSupportTicketFormScreenState();
  }
}

class _SellerSupportTicketFormScreenState
    extends State<SellerSupportTicketFormScreen> {
  static const int _maxSubjectLength = 200;
  static const int _maxContentLength = 4000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  SellerSupportCategory? _category;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _subjectController.addListener(_handleTextChanged);
    _contentController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _subjectController.removeListener(_handleTextChanged);
    _contentController.removeListener(_handleTextChanged);
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    final category = _category;

    if (!valid || category == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final created = await widget.repository.createTicket(
        category: category,
        subject: _subjectController.text,
        content: _contentController.text,
      );

      if (!mounted) {
        return;
      }

      widget.onCreated(created);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _submitError = error is ArgumentError
            ? error.message?.toString()
            : '문의를 등록하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('1:1 문의하기'), centerTitle: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                '판매자 계정',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.sellerEmail,
                readOnly: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '문의 유형',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<SellerSupportCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: '문의 유형을 선택해 주세요',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: SellerSupportCategory.values
                    .map(
                      (category) => DropdownMenuItem<SellerSupportCategory>(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _submitting
                    ? null
                    : (category) {
                        setState(() {
                          _category = category;
                        });
                      },
                validator: (category) {
                  if (category == null) {
                    return '문의 유형을 선택해 주세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                '문의 제목',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                enabled: !_submitting,
                maxLength: _maxSubjectLength,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '문의 제목을 입력해 주세요',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return '문의 제목을 입력해 주세요.';
                  }

                  if (normalized.length > _maxSubjectLength) {
                    return '문의 제목은 200자 이하로 입력해 주세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                '문의 내용',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                enabled: !_submitting,
                minLines: 9,
                maxLines: 14,
                maxLength: _maxContentLength,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '문의하실 내용을 자세히 입력해 주세요',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return '문의 내용을 입력해 주세요.';
                  }

                  if (normalized.length > _maxContentLength) {
                    return '문의 내용은 4000자 이하로 입력해 주세요.';
                  }

                  return null;
                },
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        '문의 등록',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                '문의 내용과 답변은 내 문의 내역에서 확인할 수 있습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
