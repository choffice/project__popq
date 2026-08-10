import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'business_registration_ocr_service.dart';
import 'seller_business_schedule.dart';
import 'seller_store_location_picker_screen.dart';
import 'seller_phone_input.dart';
import 'seller_store_repository.dart';
import 'seller_tag_editor.dart';
import '../auth/seller_identity_repository.dart';

enum _ImportedValueChoice { current, imported, manual }

enum _RepresentativeImageAction { keep, replace, remove }

class _SelectedStoreLocation {
  const _SelectedStoreLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.sourceLabel,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String sourceLabel;
}

class SellerStoreEditScreen extends StatefulWidget {
  const SellerStoreEditScreen({
    required this.repository,
    required this.store,
    this.identityRepository,
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStore store;
  final SellerIdentityRepository? identityRepository;

  @override
  State<SellerStoreEditScreen> createState() => _SellerStoreEditScreenState();
}

class _SellerStoreEditScreenState extends State<SellerStoreEditScreen> {
  static const List<String> _categories = <String>[
    '移댄럹',
    '?붿???,
    '踰좎씠而ㅻ━',
    '?쒖떇',
    '以묒떇',
    '?쇱떇',
    '?묒떇',
    '遺꾩떇',
    '移섑궓',
    '?쇱옄',
    '?⑥뒪?명뫖??,
    '二쇱젏',
    '?몃뱶?몃윮',
    '?앹뾽쨌?됱궗',
    '?뚮━留덉폆쨌?됱궗',
    '湲고?',
  ];

  static const double _defaultLatitude = 35.157746;
  static const double _defaultLongitude = 129.059319;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final BusinessRegistrationOcrService _ocrService =
      BusinessRegistrationOcrService();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _detailAddressController;
  late final TextEditingController _phoneController;
  late final List<String> _tags;

  late String _storeType;
  String? _representativeCategory;
  String? _existingImageUrl;
  XFile? _selectedRepresentativeImage;
  _RepresentativeImageAction _representativeImageAction =
      _RepresentativeImageAction.keep;
  _SelectedStoreLocation? _selectedLocation;
  late SellerBusinessSchedule _schedule;
  late bool _takeoutAvailable;
  late bool _dineInAvailable;
  late bool _orderAcceptingEnabled;

  bool _pickingRepresentativeImage = false;
  bool _recognizingBusinessRegistration = false;
  bool _searchingKakaoPlace = false;
  bool _searchingAddress = false;
  bool _selectingMapLocation = false;
  bool _submitting = false;
  bool _saveCompleted = false;
  bool _addressLocationWarningShown = false;

  @override
  void initState() {
    super.initState();

    final SellerStore store = widget.store;
    _nameController = TextEditingController(text: store.name);
    _descriptionController = TextEditingController(text: store.description);
    _addressController = TextEditingController(text: store.address);
    _detailAddressController = TextEditingController(text: store.detailAddress);
    _phoneController = TextEditingController(text: store.phone);
    _tags = List<String>.of(store.tags);
    _storeType = store.storeType;
    _representativeCategory = store.representativeCategory;
    _existingImageUrl = _emptyToNull(store.imageUrl);
    _schedule = store.schedule ?? SellerBusinessSchedule.legacy(
      openTime: store.openTime,
      closeTime: store.closeTime,
      closedDays: store.closedDays,
    );
    _takeoutAvailable = store.takeoutAvailable;
    _dineInAvailable = store.dineInAvailable;
    _orderAcceptingEnabled = store.orderAcceptingEnabled;

    if (store.latitude != null && store.longitude != null) {
      _selectedLocation = _SelectedStoreLocation(
        latitude: store.latitude!,
        longitude: store.longitude!,
        address: store.address?.trim() ?? '',
        sourceLabel: '湲곗〈 ?ъ뾽???꾩튂',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_submitting || _saveCompleted,
      child: Scaffold(
        appBar: AppBar(title: const Text('?ъ뾽???뺣낫 ?섏젙')),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: <Widget>[
              _buildSection(
                context,
                title: '?뺣낫 遺덈윭?ㅺ린',
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('edit-import-business-registration'),
                      onPressed: _busy || _recognizingBusinessRegistration
                          ? null
                          : _openBusinessRegistrationImport,
                      icon: _recognizingBusinessRegistration
                          ? const _ButtonProgress()
                          : const Icon(Icons.document_scanner_outlined),
                      label: Text(
                        _recognizingBusinessRegistration
                            ? '?ъ뾽?먮벑濡앹쬆 ?몄떇 以?..'
                            : '?ъ뾽?먮벑濡앹쬆 珥ъ쁺 ?먮뒗 ?좏깮',
                      ),
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('edit-import-kakao-place'),
                      onPressed: _busy || _searchingKakaoPlace
                          ? null
                          : _openKakaoPlaceImport,
                      icon: _searchingKakaoPlace
                          ? const _ButtonProgress()
                          : const Icon(Icons.map_outlined),
                      label: Text(
                        _searchingKakaoPlace ? '移댁뭅?ㅻ㏊ ?낆껜 寃??以?..' : '移댁뭅?ㅻ㏊ ?낆껜 寃??,
                      ),
                    ),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: '湲곕낯 ?뺣낫',
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    key: const Key('edit-store-type'),
                    initialValue: _storeType,
                    decoration: const InputDecoration(
                      labelText: '?ъ뾽???좏삎',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'LOCAL_STORE',
                        child: Text('?쇰컲 留ㅼ옣'),
                      ),
                      DropdownMenuItem(
                        value: 'EVENT_COMMERCE',
                        child: Text('?됱궗쨌?앹뾽 ?먮ℓ??),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value != null) {
                              setState(() => _storeType = value);
                            }
                          },
                  ),
                  const SizedBox(height: PopqSpacing.md),
                  TextFormField(
                    key: const Key('edit-store-name'),
                    controller: _nameController,
                    enabled: !_busy,
                    maxLength: 150,
                    decoration: const InputDecoration(labelText: '?ъ뾽?λ챸'),
                    validator: (String? value) =>
                        _requiredValidator(value, '?ъ뾽?λ챸???낅젰??二쇱꽭??'),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: const Key('edit-store-category'),
                    initialValue: _representativeCategory,
                    decoration: const InputDecoration(labelText: '???移댄뀒怨좊━'),
                    items: _categoryOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    validator: (String? value) =>
                        _requiredValidator(value, '???移댄뀒怨좊━瑜??좏깮??二쇱꽭??'),
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            setState(() => _representativeCategory = value);
                          },
                  ),
                  const SizedBox(height: PopqSpacing.md),
                  TextFormField(
                    key: const Key('edit-store-description'),
                    controller: _descriptionController,
                    enabled: !_busy,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '?ㅻ챸'),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  SellerPhoneInput(
                    key: const Key('edit-store-phone'),
                    controller: _phoneController,
                    enabled: !_busy,
                    identityRepository: widget.identityRepository,
                    labelText: '?꾪솕踰덊샇',
                    validator: (String? value) =>
                        _requiredValidator(value, '?꾪솕踰덊샇瑜??낅젰??二쇱꽭??'),
                  ),
                ],
              ),
              _buildAddressSection(context),
              _buildImageSection(context),
              _buildOperatingSection(context),
              _buildOrderSection(context),
              _buildSection(
                context,
                title: '寃???ㅼ썙??,
                titleAction: IconButton.filledTonal(
                  tooltip: '寃???ㅼ썙??異붽?',
                  onPressed: _busy || _tags.length >= 10 ? null : _addTag,
                  icon: const Icon(Icons.add_rounded),
                ),
                children: <Widget>[
                  SellerTagBlocks(
                    key: const Key('edit-store-tags'),
                    tags: _tags,
                    maxCount: 10,
                    enabled: !_busy,
                    onAdd: _addTag,
                    onDeleted: (tag) => setState(() => _tags.remove(tag)),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('submit-store-edit'),
                  onPressed: _busy ? null : _submit,
                  icon: _submitting
                      ? const _ButtonProgress()
                      : const Icon(Icons.save_outlined),
                  label: Text(_submitting ? '蹂寃쎌궗?????以?..' : '蹂寃쎌궗?????),
                ),
              ),
              const SizedBox(height: PopqSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  bool get _busy =>
      _submitting ||
      _pickingRepresentativeImage ||
      _recognizingBusinessRegistration ||
      _searchingKakaoPlace ||
      _searchingAddress ||
      _selectingMapLocation;

  List<String> get _categoryOptions {
    final String? current = _representativeCategory;
    return <String>[
      ..._categories,
      if (current != null && !_categories.contains(current)) current,
    ];
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    Widget? titleAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PopqSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (titleAction != null) titleAction,
                ],
              ),
              const SizedBox(height: PopqSpacing.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context) {
    final _SelectedStoreLocation? location = _selectedLocation;
    return _buildSection(
      context,
      title: '二쇱냼 諛??꾩튂',
      children: <Widget>[
        TextFormField(
          key: const Key('edit-store-address'),
          controller: _addressController,
          enabled: !_busy,
          maxLength: 255,
          decoration: const InputDecoration(labelText: '二쇱냼'),
          validator: (String? value) =>
              _requiredValidator(value, '二쇱냼瑜??낅젰??二쇱꽭??'),
          onChanged: _handleManualAddressChange,
        ),
        const SizedBox(height: PopqSpacing.sm),
        TextFormField(
          key: const Key('edit-store-detail-address'),
          controller: _detailAddressController,
          enabled: !_busy,
          maxLength: 255,
          decoration: const InputDecoration(labelText: '?곸꽭二쇱냼'),
          validator: (String? value) =>
              _requiredValidator(value, '?곸꽭二쇱냼瑜??낅젰??二쇱꽭??'),
        ),
        const SizedBox(height: PopqSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('edit-search-address'),
                onPressed: _busy ? null : _searchAddress,
                icon: _searchingAddress
                    ? const _ButtonProgress()
                    : const Icon(Icons.manage_search_outlined),
                label: const Text('二쇱냼 寃??),
              ),
            ),
            const SizedBox(width: PopqSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('edit-select-map-location'),
                onPressed: _busy ? null : _selectLocationOnMap,
                icon: _selectingMapLocation
                    ? const _ButtonProgress()
                    : const Icon(Icons.location_on_outlined),
                label: const Text('吏?꾩뿉???꾩튂 ?좏깮'),
              ),
            ),
          ],
        ),
        const SizedBox(height: PopqSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(PopqSpacing.md),
          decoration: BoxDecoration(
            color: location == null
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: location == null
              ? const Text('二쇱냼? ?쇱튂?섎뒗 ?꾩튂瑜??뺤씤??二쇱꽭??')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(location.address),
                    const SizedBox(height: PopqSpacing.xs),
                    Text(
                      '?꾨룄 ${location.latitude.toStringAsFixed(6)} 쨌 '
                      '寃쎈룄 ${location.longitude.toStringAsFixed(6)}',
                    ),
                    Text('?좏깮 諛⑹떇: ${location.sourceLabel}'),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final XFile? localImage = _selectedRepresentativeImage;
    final bool showLocalImage =
        _representativeImageAction == _RepresentativeImageAction.replace &&
        localImage != null;
    final bool showExistingImage =
        _representativeImageAction == _RepresentativeImageAction.keep &&
        _existingImageUrl != null;
    final bool hasVisibleImage = showLocalImage || showExistingImage;
    return _buildSection(
      context,
      title: '??쒖궗吏?,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: showLocalImage
                    ? Image.file(File(localImage!.path), fit: BoxFit.cover)
                    : showExistingImage
                    ? Image.network(
                        _existingImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _EmptyImagePreview(
                          label: '湲곗〈 ?ъ쭊??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
                        ),
                      )
                    : const _EmptyImagePreview(label: '?깅줉????쒖궗吏꾩씠 ?놁뒿?덈떎.'),
              ),
              Positioned(
                top: PopqSpacing.sm,
                right: PopqSpacing.sm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ImageOverlayButton(
                      key: const Key('edit-store-image-change'),
                      tooltip: '??쒖궗吏?蹂寃?,
                      icon: Icons.camera_alt_outlined,
                      onPressed: _busy ? null : _openRepresentativeImagePicker,
                    ),
                    if (hasVisibleImage) ...<Widget>[
                      const SizedBox(width: PopqSpacing.xs),
                      _ImageOverlayButton(
                        key: const Key('edit-store-image-remove'),
                        tooltip: '??쒖궗吏??쒓굅',
                        icon: Icons.delete_outline_rounded,
                        onPressed: _busy ? null : _confirmRepresentativeImageRemoval,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_representativeImageAction ==
            _RepresentativeImageAction.replace) ...<Widget>[
          const SizedBox(height: PopqSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('edit-store-image-cancel'),
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _selectedRepresentativeImage = null;
                        _representativeImageAction =
                            _RepresentativeImageAction.keep;
                      });
                    },
              icon: const Icon(Icons.undo_outlined),
              label: const Text('???ъ쭊 ?좏깮 痍⑥냼'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOperatingSection(BuildContext context) {
    return _buildSection(
      context,
      title: '?곸뾽 ?뺣낫',
      children: <Widget>[
        SellerBusinessScheduleEditor(
          initialSchedule: _schedule,
          enabled: !_busy,
          onChanged: (value) => setState(() => _schedule = value),
        ),
      ],
    );
  }

  Widget _buildOrderSection(BuildContext context) {
    return _buildSection(
      context,
      title: '二쇰Ц ?댁쁺 ?ㅼ젙',
      children: <Widget>[
        SwitchListTile(
          key: const Key('edit-store-takeout'),
          contentPadding: EdgeInsets.zero,
          title: const Text('?ъ옣 媛??),
          value: _takeoutAvailable,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _takeoutAvailable = value),
        ),
        SwitchListTile(
          key: const Key('edit-store-dine-in'),
          contentPadding: EdgeInsets.zero,
          title: const Text('留ㅼ옣 ?앹궗 媛??),
          value: _dineInAvailable,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _dineInAvailable = value),
        ),
        SwitchListTile(
          key: const Key('edit-store-order-accepting'),
          contentPadding: EdgeInsets.zero,
          title: const Text('二쇰Ц ?묒닔 媛??),
          value: _orderAcceptingEnabled,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _orderAcceptingEnabled = value),
        ),
      ],
    );
  }

  void _handleManualAddressChange(String value) {
    final _SelectedStoreLocation? location = _selectedLocation;
    if (location == null ||
        _normalizeText(location.address) == _normalizeText(value)) {
      return;
    }

    setState(() => _selectedLocation = null);
    if (!_addressLocationWarningShown) {
      _addressLocationWarningShown = true;
      _showMessage('二쇱냼媛 蹂寃쎈릺?덉뒿?덈떎. 二쇱냼 寃?됱씠??吏?꾩뿉???꾩튂瑜??ㅼ떆 ?뺤씤??二쇱꽭??');
    }
  }

  Future<void> _openRepresentativeImagePicker() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('移대찓?쇰줈 珥ъ쁺'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('媛ㅻ윭由ъ뿉???좏깮'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('痍⑥냼'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    await _pickRepresentativeImage(source);
  }

  Future<void> _confirmRepresentativeImageRemoval() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('??쒖궗吏꾩쓣 ?쒓굅?좉퉴??'),
        content: const Text(
          '??쒖궗吏??곌껐留??쒓굅?섎ŉ ?쒕쾭???낅줈?쒕맂 ?ㅼ젣 ?뚯씪? ??젣?섏? ?딆뒿?덈떎.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('?ъ쭊 ?쒓굅'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _selectedRepresentativeImage = null;
      _representativeImageAction = _RepresentativeImageAction.remove;
    });
  }

  Future<void> _pickRepresentativeImage(ImageSource source) async {
    if (_busy) {
      return;
    }
    setState(() => _pickingRepresentativeImage = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!mounted) {
        return;
      }
      if (image != null) {
        setState(() {
          _selectedRepresentativeImage = image;
          _representativeImageAction = _RepresentativeImageAction.replace;
        });
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          source == ImageSource.camera
              ? '移대찓?쇰? ?ㅽ뻾?섏? 紐삵뻽?듬땲??'
              : '媛ㅻ윭由ъ뿉???ъ쭊??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pickingRepresentativeImage = false);
      }
    }
  }

  Future<void> _openBusinessRegistrationImport() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('?ъ뾽?먮벑濡앹쬆 珥ъ쁺'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('媛ㅻ윭由ъ뿉???좏깮'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }

    setState(() => _recognizingBusinessRegistration = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (image == null) {
        return;
      }
      final BusinessRegistrationOcrResult result = await _ocrService.recognize(
        imagePath: image.path,
      );
      if (!mounted || !await _confirmOcrResult(result)) {
        return;
      }

      final String name = await _resolveImportedText(
        fieldLabel: '?ъ뾽?λ챸',
        sourceLabel: 'OCR',
        currentValue: _nameController.text,
        importedValue: result.businessName,
      );
      if (!mounted) {
        return;
      }
      final String address = await _resolveImportedText(
        fieldLabel: '二쇱냼',
        sourceLabel: 'OCR',
        currentValue: _addressController.text,
        importedValue: result.businessAddress,
      );
      if (!mounted) {
        return;
      }
      _applyImportedText(name: name, address: address, sourceLabel: 'OCR');
    } on BusinessRegistrationOcrException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('?ъ뾽?먮벑濡앹쬆???몄떇?섎뒗 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎.');
      }
    } finally {
      if (mounted) {
        setState(() => _recognizingBusinessRegistration = false);
      }
    }
  }

  Future<bool> _confirmOcrResult(BusinessRegistrationOcrResult result) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('?ъ뾽?먮벑濡앹쬆 ?몄떇 寃곌낵'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('?ъ뾽?먮벑濡앸쾲?? ${result.businessNumber}'),
              Text('?곹샇紐? ${result.businessName ?? '?몄떇?섏? ?딆쓬'}'),
              Text('??쒖옄紐? ${result.representativeName ?? '?몄떇?섏? ?딆쓬'}'),
              Text('?ъ뾽??二쇱냼: ${result.businessAddress ?? '?몄떇?섏? ?딆쓬'}'),
              const SizedBox(height: PopqSpacing.md),
              const Text('?ъ뾽?먮벑濡앸쾲?몄? ??쒖옄紐낆? ?뺤씤?⑹씠硫???ν븯吏 ?딆뒿?덈떎.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed:
                result.businessName == null && result.businessAddress == null
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: const Text('?뺣낫 ?곸슜'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _openKakaoPlaceImport() async {
    final String? query = await _requestSearchQuery(
      title: '移댁뭅?ㅻ㏊ ?낆껜 寃??,
      initialValue: <String>[
        _addressController.text.trim(),
        _nameController.text.trim(),
      ].where((String value) => value.isNotEmpty).join(' '),
    );
    if (query == null || !mounted) {
      return;
    }
    setState(() => _searchingKakaoPlace = true);
    try {
      final List<SellerKakaoPlaceSearchResult> results = await widget.repository
          .searchPlaces(query);
      if (!mounted) {
        return;
      }
      if (results.isEmpty) {
        _showMessage('移댁뭅?ㅻ㏊?먯꽌 ?낆껜瑜?李얠? 紐삵뻽?듬땲??');
        return;
      }
      final SellerKakaoPlaceSearchResult? selected = await _selectKakaoPlace(
        results,
      );
      if (selected == null || !mounted) {
        return;
      }
      await _applyKakaoPlace(selected);
    } on PopqFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('移댁뭅?ㅻ㏊ ?낆껜瑜?寃?됲븯??以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎.');
      }
    } finally {
      if (mounted) {
        setState(() => _searchingKakaoPlace = false);
      }
    }
  }

  Future<void> _applyKakaoPlace(SellerKakaoPlaceSearchResult place) async {
    final String name = await _resolveImportedText(
      fieldLabel: '?ъ뾽?λ챸',
      sourceLabel: '移댁뭅??,
      currentValue: _nameController.text,
      importedValue: place.placeName,
    );
    if (!mounted) {
      return;
    }
    final String address = await _resolveImportedText(
      fieldLabel: '二쇱냼',
      sourceLabel: '移댁뭅??,
      currentValue: _addressController.text,
      importedValue: place.displayAddress,
    );
    if (!mounted) {
      return;
    }
    final String phone = await _resolveImportedText(
      fieldLabel: '?꾪솕踰덊샇',
      sourceLabel: '移댁뭅??,
      currentValue: _phoneController.text,
      importedValue: place.phone,
    );
    if (!mounted) {
      return;
    }

    final Set<String> placeAddresses = <String>{
      if (_emptyToNull(place.roadAddressName) != null)
        _normalizeText(place.roadAddressName!),
      if (_emptyToNull(place.addressName) != null)
        _normalizeText(place.addressName!),
    };
    final bool addressMatches = placeAddresses.contains(
      _normalizeText(address),
    );
    setState(() {
      _nameController.text = name;
      _addressController.text = address;
      _phoneController.text = phone;
      _selectedLocation = addressMatches
          ? _SelectedStoreLocation(
              latitude: place.latitude,
              longitude: place.longitude,
              address: address,
              sourceLabel: '移댁뭅???낆껜 寃??,
            )
          : null;
    });
    _showMessage(
      addressMatches
          ? '移댁뭅???낆껜 ?뺣낫? ?꾩튂瑜?諛섏쁺?덉뒿?덈떎.'
          : '?낆껜 ?뺣낫??諛섏쁺?덉?留?二쇱냼媛 ?щ씪 ?꾩튂瑜???ν븯吏 ?딆븯?듬땲?? ?꾩튂瑜??ㅼ떆 ?뺤씤??二쇱꽭??',
    );
  }

  Future<void> _searchAddress() async {
    final String current = _addressController.text.trim();
    final String? query = await _requestSearchQuery(
      title: '二쇱냼 寃??,
      initialValue: current,
    );
    if (query == null || !mounted) {
      return;
    }
    setState(() => _searchingAddress = true);
    try {
      final List<SellerAddressSearchResult> results = await widget.repository
          .searchAddresses(query);
      if (!mounted) {
        return;
      }
      if (results.isEmpty) {
        _showMessage('二쇱냼 寃??寃곌낵媛 ?놁뒿?덈떎.');
        return;
      }
      final SellerAddressSearchResult? selected = await _selectAddress(results);
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        _addressController.text = selected.addressName;
        _selectedLocation = _SelectedStoreLocation(
          latitude: selected.latitude,
          longitude: selected.longitude,
          address: selected.addressName,
          sourceLabel: '二쇱냼 寃??,
        );
      });
      _showMessage('寃?됲븳 二쇱냼? ?꾩튂瑜?諛섏쁺?덉뒿?덈떎.');
    } on PopqFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('二쇱냼瑜?寃?됲븯??以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎.');
      }
    } finally {
      if (mounted) {
        setState(() => _searchingAddress = false);
      }
    }
  }

  Future<void> _selectLocationOnMap() async {
    final String address = _addressController.text.trim();
    if (address.isEmpty) {
      _showMessage('吏???꾩튂瑜??좏깮?섍린 ?꾩뿉 二쇱냼瑜??낅젰??二쇱꽭??');
      return;
    }
    final _SelectedStoreLocation? location = _selectedLocation;
    final double initialLatitude =
        location?.latitude ?? widget.store.latitude ?? _defaultLatitude;
    final double initialLongitude =
        location?.longitude ?? widget.store.longitude ?? _defaultLongitude;

    final SellerMapLocationPickResult? picked = await Navigator.of(context)
        .push<SellerMapLocationPickResult>(
          MaterialPageRoute<SellerMapLocationPickResult>(
            builder: (BuildContext context) => SellerStoreLocationPickerScreen(
              initialLatitude: initialLatitude,
              initialLongitude: initialLongitude,
              addressLabel: address,
            ),
          ),
        );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectingMapLocation = true);
    try {
      final SellerReverseGeocodeResult result = await widget.repository
          .reverseGeocode(
            latitude: picked.latitude,
            longitude: picked.longitude,
          );
      if (!mounted) {
        return;
      }
      final String resolvedAddress = await _resolveImportedText(
        fieldLabel: '二쇱냼',
        sourceLabel: '吏?꾩뿉???좏깮???꾩튂',
        currentValue: address,
        importedValue: result.displayAddress,
      );
      if (!mounted) {
        return;
      }
      final bool matches = result.addressCandidates
          .map(_normalizeText)
          .contains(_normalizeText(resolvedAddress));
      setState(() {
        _addressController.text = resolvedAddress;
        _selectedLocation = matches
            ? _SelectedStoreLocation(
                latitude: result.latitude,
                longitude: result.longitude,
                address: resolvedAddress,
                sourceLabel: '吏??吏곸젒 ?좏깮',
              )
            : null;
      });
      _showMessage(
        matches
            ? '吏?꾩뿉???좏깮??二쇱냼? ?꾩튂瑜?諛섏쁺?덉뒿?덈떎.'
            : '?낅젰 二쇱냼瑜??좎??덉뒿?덈떎. ?꾩옱 二쇱냼??留욌뒗 ?꾩튂瑜??ㅼ떆 ?좏깮??二쇱꽭??',
      );
    } on PopqFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('?좏깮???꾩튂??二쇱냼瑜??뺤씤?섏? 紐삵뻽?듬땲??');
      }
    } finally {
      if (mounted) {
        setState(() => _selectingMapLocation = false);
      }
    }
  }

  Future<String?> _requestSearchQuery({
    required String title,
    required String initialValue,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: '寃?됱뼱'),
          onSubmitted: (String value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () {
              final String query = controller.text.trim();
              if (query.isNotEmpty) {
                Navigator.of(dialogContext).pop(query);
              }
            },
            child: const Text('寃??),
          ),
        ],
      ),
    );
    return result;
  }

  Future<SellerKakaoPlaceSearchResult?> _selectKakaoPlace(
    List<SellerKakaoPlaceSearchResult> results,
  ) {
    return showDialog<SellerKakaoPlaceSearchResult>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('?낆껜 ?좏깮'),
        children: results
            .map(
              (SellerKakaoPlaceSearchResult place) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(place),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: PopqSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(place.placeName),
                      Text(place.displayAddress),
                      if (_emptyToNull(place.phone) != null) Text(place.phone!),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<SellerAddressSearchResult?> _selectAddress(
    List<SellerAddressSearchResult> results,
  ) {
    return showDialog<SellerAddressSearchResult>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('二쇱냼 ?좏깮'),
        children: results
            .map(
              (SellerAddressSearchResult result) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(result),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: PopqSpacing.sm),
                  child: Text(result.addressName),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<String> _resolveImportedText({
    required String fieldLabel,
    required String sourceLabel,
    required String currentValue,
    required String? importedValue,
  }) async {
    final String current = currentValue.trim();
    final String imported = importedValue?.trim() ?? '';
    if (imported.isEmpty ||
        _normalizeText(current) == _normalizeText(imported)) {
      return current;
    }
    if (current.isEmpty) {
      return imported;
    }

    final TextEditingController manual = TextEditingController(text: current);
    _ImportedValueChoice choice = _ImportedValueChoice.current;
    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text('$fieldLabel ?뺣낫 ?뺤씤'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RadioGroup<_ImportedValueChoice>(
                      groupValue: choice,
                      onChanged: (_ImportedValueChoice? value) {
                        if (value != null) {
                          setDialogState(() => choice = value);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          RadioListTile<_ImportedValueChoice>(
                            value: _ImportedValueChoice.current,
                            title: const Text('?꾩옱 媛??좎?'),
                            subtitle: Text(current),
                          ),
                          RadioListTile<_ImportedValueChoice>(
                            value: _ImportedValueChoice.imported,
                            title: Text('$sourceLabel 媛??ъ슜'),
                            subtitle: Text(imported),
                          ),
                          const RadioListTile<_ImportedValueChoice>(
                            value: _ImportedValueChoice.manual,
                            title: Text('吏곸젒 ?낅젰'),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: manual,
                      enabled: choice == _ImportedValueChoice.manual,
                      decoration: InputDecoration(
                        labelText: '$fieldLabel 吏곸젒 ?낅젰',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                FilledButton(
                  onPressed: () {
                    final String resolved = switch (choice) {
                      _ImportedValueChoice.current => current,
                      _ImportedValueChoice.imported => imported,
                      _ImportedValueChoice.manual => manual.text.trim(),
                    };
                    if (resolved.isNotEmpty) {
                      Navigator.of(dialogContext).pop(resolved);
                    }
                  },
                  child: const Text('?뺤씤'),
                ),
              ],
            ),
      ),
    );
    return result ?? current;
  }

  void _applyImportedText({
    required String name,
    required String address,
    required String sourceLabel,
  }) {
    final _SelectedStoreLocation? previous = _selectedLocation;
    final bool addressChanged =
        previous != null &&
        _normalizeText(previous.address) != _normalizeText(address);
    setState(() {
      _nameController.text = name;
      _addressController.text = address;
      if (addressChanged) {
        _selectedLocation = null;
      }
    });
    _showMessage(
      addressChanged
          ? '$sourceLabel ?뺣낫瑜?諛섏쁺?덉뒿?덈떎. 二쇱냼媛 蹂寃쎈릺???꾩튂瑜??ㅼ떆 ?뺤씤??二쇱꽭??'
          : '$sourceLabel ?뺣낫瑜?諛섏쁺?덉뒿?덈떎.',
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('?꾩닔 ?낅젰 ??ぉ???뺤씤??二쇱꽭??');
      return;
    }
    final String? scheduleError = _schedule.validationMessage;
    if (scheduleError != null) {
      _showMessage(scheduleError);
      return;
    }
    if (!_takeoutAvailable && !_dineInAvailable) {
      _showMessage('?ъ옣 ?먮뒗 留ㅼ옣 ?앹궗 以??섎굹??媛?ν빐???⑸땲??');
      return;
    }

    setState(() => _submitting = true);
    try {
      String? resolvedImageUrl;
      switch (_representativeImageAction) {
        case _RepresentativeImageAction.keep:
          resolvedImageUrl = _existingImageUrl;
          break;
        case _RepresentativeImageAction.replace:
          final XFile selectedImage = _selectedRepresentativeImage!;
          resolvedImageUrl = await widget.repository.uploadRepresentativeImage(
            selectedImage.path,
          );
          break;
        case _RepresentativeImageAction.remove:
          resolvedImageUrl = '';
          break;
      }

      final _SelectedStoreLocation? location = _selectedLocation;
      final SellerStore updated = await widget.repository.update(
        widget.store.storeId,
        storeType: _storeType,
        name: _nameController.text.trim(),
        description: _emptyToNull(_descriptionController.text),
        address: _addressController.text.trim(),
        detailAddress: _detailAddressController.text.trim(),
        representativeCategory: _representativeCategory,
        imageUrl: resolvedImageUrl,
        phone: _phoneController.text.trim(),
        latitude: location?.latitude,
        longitude: location?.longitude,
        openTime: _schedule.legacyOpenTimeForApi,
        closeTime: _schedule.legacyCloseTimeForApi,
        closedDays: _schedule.legacyClosedDays,
        schedule: _schedule,
        takeoutAvailable: _takeoutAvailable,
        dineInAvailable: _dineInAvailable,
        orderAcceptingEnabled: _orderAcceptingEnabled,
        tags: List<String>.unmodifiable(_tags),
      );
      if (!mounted) {
        return;
      }
      setState(() => _saveCompleted = true);
      Navigator.of(context).pop<SellerStore>(updated);
    } on PopqFailure catch (failure) {
      if (mounted) {
        setState(() => _submitting = false);
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _showMessage('?ъ뾽???뺣낫瑜??섏젙?섏? 紐삵뻽?듬땲?? ?좎떆 ???ㅼ떆 ?쒕룄??二쇱꽭??');
      }
    }
  }

  Future<void> _addTag() async {
    final String? tag = await showSellerTagInputDialog(
      context,
      existingTags: _tags,
    );
    if (tag != null && mounted) {
      setState(() => _tags.add(tag));
    }
  }

  String? _requiredValidator(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  static String? _emptyToNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(SnackBar(content: Text(message)));
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _ImageOverlayButton extends StatelessWidget {
  const _ImageOverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      shape: const CircleBorder(),
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _EmptyImagePreview extends StatelessWidget {
  const _EmptyImagePreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.image_not_supported_outlined, size: 42),
            const SizedBox(height: PopqSpacing.sm),
            Text(label),
          ],
        ),
      ),
    );
  }
}

