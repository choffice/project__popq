import 'package:flutter/material.dart';

import '../auth/seller_identity_repository.dart';

class SellerPhoneInput extends StatefulWidget {
  const SellerPhoneInput({
    required this.controller,
    required this.enabled,
    this.identityRepository,
    this.labelText = '사업장 연락처',
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final SellerIdentityRepository? identityRepository;
  final String labelText;
  final String? Function(String?)? validator;

  @override
  State<SellerPhoneInput> createState() => _SellerPhoneInputState();
}

class _SellerPhoneInputState extends State<SellerPhoneInput> {
  static const List<String> _prefixes = <String>[
    '010',
    '070',
    '02',
    '031',
    '032',
    '033',
    '041',
    '042',
    '043',
    '044',
    '051',
    '052',
    '053',
    '054',
    '055',
    '061',
    '062',
    '063',
    '064',
  ];

  String _selectedPrefix = 'DIRECT';
  bool _usingMyPhone = false;
  bool _loadingMyPhone = false;

  @override
  void initState() {
    super.initState();
    _selectedPrefix = _prefixFor(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 116,
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>(_selectedPrefix),
                initialValue: _selectedPrefix,
                decoration: const InputDecoration(labelText: '번호 구분'),
                items: <DropdownMenuItem<String>>[
                  ..._prefixes.map(
                    (String prefix) => DropdownMenuItem<String>(
                      value: prefix,
                      child: Text(prefix),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'DIRECT',
                    child: Text('직접입력'),
                  ),
                ],
                onChanged: widget.enabled ? _changePrefix : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                enabled: widget.enabled,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  hintText: '예: 051-123-4567',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: widget.validator,
              ),
            ),
          ],
        ),
        if (widget.identityRepository != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _usingMyPhone,
            onChanged: !widget.enabled || _loadingMyPhone
                ? null
                : (bool? value) => _toggleMyPhone(value ?? false),
            title: const Text('내 정보의 연락처 사용'),
            subtitle: _loadingMyPhone ? const Text('연락처를 불러오는 중...') : null,
          ),
      ],
    );
  }

  void _changePrefix(String? prefix) {
    if (prefix == null) return;
    setState(() {
      _selectedPrefix = prefix;
      _usingMyPhone = false;
    });
    if (prefix == 'DIRECT') return;

    final String current = widget.controller.text.trim();
    final String suffix = current.contains('-')
        ? current.substring(current.indexOf('-') + 1)
        : '';
    widget.controller.text = suffix.isEmpty ? '$prefix' : '$prefix$suffix';
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  Future<void> _toggleMyPhone(bool useMyPhone) async {
    if (!useMyPhone) {
      setState(() => _usingMyPhone = false);
      return;
    }
    setState(() => _loadingMyPhone = true);
    try {
      final SellerIdentity identity =
          await widget.identityRepository!.getCurrent();
      if (!mounted) return;
      final String phone = identity.phone?.trim() ?? '';
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 정보에 저장된 연락처가 없습니다.')),
        );
        return;
      }
      widget.controller.text = phone;
      setState(() {
        _usingMyPhone = true;
        _selectedPrefix = _prefixFor(phone);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 연락처를 불러오지 못했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMyPhone = false);
    }
  }

  String _prefixFor(String phone) {
    final String normalized = phone.trim();
    for (final String prefix in _prefixes) {
      if (normalized == prefix || normalized.startsWith('$prefix-')) {
        return prefix;
      }
    }
    return 'DIRECT';
  }
}
