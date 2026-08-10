import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../auth/seller_identity_repository.dart';

class SellerPhoneInput extends StatefulWidget {
  const SellerPhoneInput({
    required this.controller,
    required this.enabled,
    this.identityRepository,
    this.labelText = '?ъ뾽???곕씫泥?,
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
                decoration: const InputDecoration(labelText: '踰덊샇 援щ텇'),
                items: <DropdownMenuItem<String>>[
                  ..._prefixes.map(
                    (String prefix) => DropdownMenuItem<String>(
                      value: prefix,
                      child: Text(prefix),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'DIRECT',
                    child: Text('吏곸젒?낅젰'),
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
                  hintText: '?? 051-123-4567',
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
            title: const Text('???뺣낫???곕씫泥??ъ슜'),
            subtitle: _loadingMyPhone ? const Text('?곕씫泥섎? 遺덈윭?ㅻ뒗 以?..') : null,
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
    widget.controller.text = suffix.isEmpty ? '$prefix-' : '$prefix-$suffix';
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
        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(content: Text('???뺣낫????λ맂 ?곕씫泥섍? ?놁뒿?덈떎.')),
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
        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(content: Text('???곕씫泥섎? 遺덈윭?ㅼ? 紐삵뻽?듬땲??')),
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

