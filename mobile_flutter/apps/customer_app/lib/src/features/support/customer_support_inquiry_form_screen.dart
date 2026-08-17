import 'package:flutter/material.dart';

import 'customer_support_inquiry.dart';
import 'customer_support_repository.dart';
import 'customer_support_types.dart';

class CustomerSupportInquiryFormScreen extends StatefulWidget {
  const CustomerSupportInquiryFormScreen({
    required this.repository,
    required this.customerEmail,
    required this.onCreated,
    super.key,
  });

  final CustomerSupportRepository repository;
  final String customerEmail;
  final ValueChanged<CustomerSupportInquiryDetail> onCreated;

  @override
  State<CustomerSupportInquiryFormScreen> createState() {
    return _CustomerSupportInquiryFormScreenState();
  }
}

class _CustomerSupportInquiryFormScreenState
    extends State<CustomerSupportInquiryFormScreen> {
  static const int _maxTitleLength = 200;
  static const int _maxContentLength = 1000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  CustomerSupportCategory? _category;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    setState(() {});
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    final category = _category;

    if (category == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final created = await widget.repository.createInquiry(
        category: category,
        title: _titleController.text,
        content: _contentController.text,
      );

      if (!mounted) {
        return;
      }

      widget.onCreated(created);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _submitError = '문의를 등록하지 못했어요. 잠시 후 다시 시도해 주세요.';
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
                '이메일',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.customerEmail,
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
              DropdownButtonFormField<CustomerSupportCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: '문의 유형을 선택해 주세요',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: CustomerSupportCategory.values
                    .map(
                      (category) => DropdownMenuItem<CustomerSupportCategory>(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _category = value;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return '문의 유형을 선택해 주세요.';
                  }

                  return null;
                },
              ),
              Text(
                '문의 제목',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                enabled: !_submitting,
                maxLength: _maxTitleLength,
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

                  if (normalized.length > _maxTitleLength) {
                    return '문의 제목은 200자 이하로 입력해 주세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
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
                  hintText: '문의하실 내용을 입력해 주세요',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return '문의 내용을 입력해 주세요.';
                  }

                  return null;
                },
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 8),
                Text(_submitError!, style: TextStyle(color: colorScheme.error)),
              ],
              const SizedBox(height: 20),
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
                        '문의하기',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
