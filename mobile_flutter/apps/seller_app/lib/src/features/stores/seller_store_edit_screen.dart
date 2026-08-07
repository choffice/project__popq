import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'business_registration_ocr_service.dart';
import 'seller_store_location_picker_screen.dart';
import 'seller_store_repository.dart';

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
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStore store;

  @override
  State<SellerStoreEditScreen> createState() => _SellerStoreEditScreenState();
}

class _SellerStoreEditScreenState extends State<SellerStoreEditScreen> {
  static const List<String> _categories = <String>[
    '카페',
    '디저트',
    '베이커리',
    '한식',
    '중식',
    '일식',
    '양식',
    '분식',
    '치킨',
    '피자',
    '패스트푸드',
    '주점',
    '푸드트럭',
    '팝업·행사',
    '플리마켓·행사',
    '기타',
  ];

  static const Map<String, String> _days = <String, String>{
    'MONDAY': '월',
    'TUESDAY': '화',
    'WEDNESDAY': '수',
    'THURSDAY': '목',
    'FRIDAY': '금',
    'SATURDAY': '토',
    'SUNDAY': '일',
  };

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
  late final TextEditingController _tagsController;

  late String _storeType;
  String? _representativeCategory;
  String? _existingImageUrl;
  XFile? _selectedRepresentativeImage;
  _RepresentativeImageAction _representativeImageAction =
      _RepresentativeImageAction.keep;
  _SelectedStoreLocation? _selectedLocation;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  late final Set<String> _closedDays;
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
    _tagsController = TextEditingController(text: store.tags.join(', '));
    _storeType = store.storeType;
    _representativeCategory = store.representativeCategory;
    _existingImageUrl = _emptyToNull(store.imageUrl);
    _openTime = _parseTime(store.openTime);
    _closeTime = _parseTime(store.closeTime);
    _closedDays = <String>{...store.closedDays};
    _takeoutAvailable = store.takeoutAvailable;
    _dineInAvailable = store.dineInAvailable;
    _orderAcceptingEnabled = store.orderAcceptingEnabled;

    if (store.latitude != null && store.longitude != null) {
      _selectedLocation = _SelectedStoreLocation(
        latitude: store.latitude!,
        longitude: store.longitude!,
        address: store.address?.trim() ?? '',
        sourceLabel: '기존 사업장 위치',
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
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_submitting || _saveCompleted,
      child: Scaffold(
        appBar: AppBar(title: const Text('사업장 정보 수정')),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: <Widget>[
              _buildSection(
                context,
                title: '정보 불러오기',
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
                            ? '사업자등록증 인식 중...'
                            : '사업자등록증 촬영 또는 선택',
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
                        _searchingKakaoPlace ? '카카오맵 업체 검색 중...' : '카카오맵 업체 검색',
                      ),
                    ),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: '기본 정보',
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    key: const Key('edit-store-type'),
                    initialValue: _storeType,
                    decoration: const InputDecoration(
                      labelText: '사업장 유형',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'LOCAL_STORE',
                        child: Text('일반 매장'),
                      ),
                      DropdownMenuItem(
                        value: 'EVENT_COMMERCE',
                        child: Text('행사·팝업 판매점'),
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
                    decoration: const InputDecoration(labelText: '사업장명'),
                    validator: (String? value) =>
                        _requiredValidator(value, '사업장명을 입력해 주세요.'),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: const Key('edit-store-category'),
                    initialValue: _representativeCategory,
                    decoration: const InputDecoration(labelText: '대표 카테고리'),
                    items: _categoryOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    validator: (String? value) =>
                        _requiredValidator(value, '대표 카테고리를 선택해 주세요.'),
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
                    decoration: const InputDecoration(labelText: '설명'),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  TextFormField(
                    key: const Key('edit-store-phone'),
                    controller: _phoneController,
                    enabled: !_busy,
                    maxLength: 30,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '전화번호'),
                    validator: (String? value) =>
                        _requiredValidator(value, '전화번호를 입력해 주세요.'),
                  ),
                ],
              ),
              _buildAddressSection(context),
              _buildImageSection(context),
              _buildOperatingSection(context),
              _buildOrderSection(context),
              _buildSection(
                context,
                title: '검색 키워드',
                children: <Widget>[
                  TextFormField(
                    key: const Key('edit-store-tags'),
                    controller: _tagsController,
                    enabled: !_busy,
                    maxLength: 310,
                    decoration: const InputDecoration(
                      labelText: '검색 키워드',
                      hintText: '쉼표로 구분해 최대 10개까지 입력',
                    ),
                    validator: _validateTags,
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
                  label: Text(_submitting ? '변경사항 저장 중...' : '변경사항 저장'),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PopqSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
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
      title: '주소 및 위치',
      children: <Widget>[
        TextFormField(
          key: const Key('edit-store-address'),
          controller: _addressController,
          enabled: !_busy,
          maxLength: 255,
          decoration: const InputDecoration(labelText: '주소'),
          validator: (String? value) =>
              _requiredValidator(value, '주소를 입력해 주세요.'),
          onChanged: _handleManualAddressChange,
        ),
        const SizedBox(height: PopqSpacing.sm),
        TextFormField(
          key: const Key('edit-store-detail-address'),
          controller: _detailAddressController,
          enabled: !_busy,
          maxLength: 255,
          decoration: const InputDecoration(labelText: '상세주소'),
          validator: (String? value) =>
              _requiredValidator(value, '상세주소를 입력해 주세요.'),
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
                label: const Text('주소 검색'),
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
                label: const Text('지도에서 위치 선택'),
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
              ? const Text('주소와 일치하는 위치를 확인해 주세요.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(location.address),
                    const SizedBox(height: PopqSpacing.xs),
                    Text(
                      '위도 ${location.latitude.toStringAsFixed(6)} · '
                      '경도 ${location.longitude.toStringAsFixed(6)}',
                    ),
                    Text('선택 방식: ${location.sourceLabel}'),
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
      title: '대표사진',
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
                          label: '기존 사진을 불러오지 못했습니다.',
                        ),
                      )
                    : const _EmptyImagePreview(label: '등록된 대표사진이 없습니다.'),
              ),
              Positioned(
                top: PopqSpacing.sm,
                right: PopqSpacing.sm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ImageOverlayButton(
                      key: const Key('edit-store-image-change'),
                      tooltip: '대표사진 변경',
                      icon: Icons.camera_alt_outlined,
                      onPressed: _busy ? null : _openRepresentativeImagePicker,
                    ),
                    if (hasVisibleImage) ...<Widget>[
                      const SizedBox(width: PopqSpacing.xs),
                      _ImageOverlayButton(
                        key: const Key('edit-store-image-remove'),
                        tooltip: '대표사진 제거',
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
              label: const Text('새 사진 선택 취소'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOperatingSection(BuildContext context) {
    return _buildSection(
      context,
      title: '영업 정보',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('edit-store-open-time'),
                onPressed: _busy ? null : () => _selectTime(isOpenTime: true),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  _openTime == null ? '시작 시간' : _formatTime(_openTime!),
                ),
              ),
            ),
            const SizedBox(width: PopqSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('edit-store-close-time'),
                onPressed: _busy ? null : () => _selectTime(isOpenTime: false),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  _closeTime == null ? '종료 시간' : _formatTime(_closeTime!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PopqSpacing.md),
        const Text('휴무일'),
        const SizedBox(height: PopqSpacing.sm),
        Wrap(
          spacing: PopqSpacing.sm,
          runSpacing: PopqSpacing.sm,
          children: _days.entries
              .map((MapEntry<String, String> entry) {
                return FilterChip(
                  label: Text(entry.value),
                  selected: _closedDays.contains(entry.key),
                  onSelected: _busy
                      ? null
                      : (bool selected) {
                          setState(() {
                            if (selected) {
                              _closedDays.add(entry.key);
                            } else {
                              _closedDays.remove(entry.key);
                            }
                          });
                        },
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildOrderSection(BuildContext context) {
    return _buildSection(
      context,
      title: '주문 운영 설정',
      children: <Widget>[
        SwitchListTile(
          key: const Key('edit-store-takeout'),
          contentPadding: EdgeInsets.zero,
          title: const Text('포장 가능'),
          value: _takeoutAvailable,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _takeoutAvailable = value),
        ),
        SwitchListTile(
          key: const Key('edit-store-dine-in'),
          contentPadding: EdgeInsets.zero,
          title: const Text('매장 식사 가능'),
          value: _dineInAvailable,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _dineInAvailable = value),
        ),
        SwitchListTile(
          key: const Key('edit-store-order-accepting'),
          contentPadding: EdgeInsets.zero,
          title: const Text('주문 접수 가능'),
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
      _showMessage('주소가 변경되었습니다. 주소 검색이나 지도에서 위치를 다시 확인해 주세요.');
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
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('취소'),
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
        title: const Text('대표사진을 제거할까요?'),
        content: const Text(
          '대표사진 연결만 제거되며 서버에 업로드된 실제 파일은 삭제되지 않습니다.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('사진 제거'),
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
              ? '카메라를 실행하지 못했습니다.'
              : '갤러리에서 사진을 불러오지 못했습니다.',
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
              title: const Text('사업자등록증 촬영'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
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
        fieldLabel: '사업장명',
        sourceLabel: 'OCR',
        currentValue: _nameController.text,
        importedValue: result.businessName,
      );
      if (!mounted) {
        return;
      }
      final String address = await _resolveImportedText(
        fieldLabel: '주소',
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
        _showMessage('사업자등록증을 인식하는 중 오류가 발생했습니다.');
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
        title: const Text('사업자등록증 인식 결과'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('사업자등록번호: ${result.businessNumber}'),
              Text('상호명: ${result.businessName ?? '인식되지 않음'}'),
              Text('대표자명: ${result.representativeName ?? '인식되지 않음'}'),
              Text('사업장 주소: ${result.businessAddress ?? '인식되지 않음'}'),
              const SizedBox(height: PopqSpacing.md),
              const Text('사업자등록번호와 대표자명은 확인용이며 저장하지 않습니다.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed:
                result.businessName == null && result.businessAddress == null
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: const Text('정보 적용'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _openKakaoPlaceImport() async {
    final String? query = await _requestSearchQuery(
      title: '카카오맵 업체 검색',
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
        _showMessage('카카오맵에서 업체를 찾지 못했습니다.');
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
        _showMessage('카카오맵 업체를 검색하는 중 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _searchingKakaoPlace = false);
      }
    }
  }

  Future<void> _applyKakaoPlace(SellerKakaoPlaceSearchResult place) async {
    final String name = await _resolveImportedText(
      fieldLabel: '사업장명',
      sourceLabel: '카카오',
      currentValue: _nameController.text,
      importedValue: place.placeName,
    );
    if (!mounted) {
      return;
    }
    final String address = await _resolveImportedText(
      fieldLabel: '주소',
      sourceLabel: '카카오',
      currentValue: _addressController.text,
      importedValue: place.displayAddress,
    );
    if (!mounted) {
      return;
    }
    final String phone = await _resolveImportedText(
      fieldLabel: '전화번호',
      sourceLabel: '카카오',
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
              sourceLabel: '카카오 업체 검색',
            )
          : null;
    });
    _showMessage(
      addressMatches
          ? '카카오 업체 정보와 위치를 반영했습니다.'
          : '업체 정보는 반영했지만 주소가 달라 위치를 저장하지 않았습니다. 위치를 다시 확인해 주세요.',
    );
  }

  Future<void> _searchAddress() async {
    final String current = _addressController.text.trim();
    final String? query = await _requestSearchQuery(
      title: '주소 검색',
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
        _showMessage('주소 검색 결과가 없습니다.');
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
          sourceLabel: '주소 검색',
        );
      });
      _showMessage('검색한 주소와 위치를 반영했습니다.');
    } on PopqFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('주소를 검색하는 중 오류가 발생했습니다.');
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
      _showMessage('지도 위치를 선택하기 전에 주소를 입력해 주세요.');
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
        fieldLabel: '주소',
        sourceLabel: '지도에서 선택한 위치',
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
                sourceLabel: '지도 직접 선택',
              )
            : null;
      });
      _showMessage(
        matches
            ? '지도에서 선택한 주소와 위치를 반영했습니다.'
            : '입력 주소를 유지했습니다. 현재 주소에 맞는 위치를 다시 선택해 주세요.',
      );
    } on PopqFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('선택한 위치의 주소를 확인하지 못했습니다.');
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
          decoration: const InputDecoration(labelText: '검색어'),
          onSubmitted: (String value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final String query = controller.text.trim();
              if (query.isNotEmpty) {
                Navigator.of(dialogContext).pop(query);
              }
            },
            child: const Text('검색'),
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
        title: const Text('업체 선택'),
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
        title: const Text('주소 선택'),
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
              title: Text('$fieldLabel 정보 확인'),
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
                            title: const Text('현재 값 유지'),
                            subtitle: Text(current),
                          ),
                          RadioListTile<_ImportedValueChoice>(
                            value: _ImportedValueChoice.imported,
                            title: Text('$sourceLabel 값 사용'),
                            subtitle: Text(imported),
                          ),
                          const RadioListTile<_ImportedValueChoice>(
                            value: _ImportedValueChoice.manual,
                            title: Text('직접 입력'),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: manual,
                      enabled: choice == _ImportedValueChoice.manual,
                      decoration: InputDecoration(
                        labelText: '$fieldLabel 직접 입력',
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
                  child: const Text('확인'),
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
          ? '$sourceLabel 정보를 반영했습니다. 주소가 변경되어 위치를 다시 확인해 주세요.'
          : '$sourceLabel 정보를 반영했습니다.',
    );
  }

  Future<void> _selectTime({required bool isOpenTime}) async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: (isOpenTime ? _openTime : _closeTime) ?? TimeOfDay.now(),
      helpText: isOpenTime ? '영업 시작 시간' : '영업 종료 시간',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (isOpenTime) {
        _openTime = selected;
      } else {
        _closeTime = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('필수 입력 항목을 확인해 주세요.');
      return;
    }
    if (_openTime == null || _closeTime == null) {
      _showMessage('영업 시작 시간과 종료 시간을 선택해 주세요.');
      return;
    }
    if (!_takeoutAvailable && !_dineInAvailable) {
      _showMessage('포장 또는 매장 식사 중 하나는 가능해야 합니다.');
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
        openTime: _toApiTime(_openTime!),
        closeTime: _toApiTime(_closeTime!),
        closedDays: _days.keys
            .where(_closedDays.contains)
            .toList(growable: false),
        takeoutAvailable: _takeoutAvailable,
        dineInAvailable: _dineInAvailable,
        orderAcceptingEnabled: _orderAcceptingEnabled,
        tags: _parseTags(),
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
        _showMessage('사업장 정보를 수정하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  List<String> _parseTags() {
    final List<String> tags = <String>[];
    for (final String raw in _tagsController.text.split(',')) {
      final String tag = raw
          .trim()
          .replaceFirst(RegExp(r'^#+'), '')
          .toLowerCase();
      if (tag.isNotEmpty && !tags.contains(tag)) {
        tags.add(tag);
      }
    }
    return List<String>.unmodifiable(tags);
  }

  String? _validateTags(String? value) {
    final List<String> tags = _parseTags();
    if (tags.length > 10) {
      return '검색 키워드는 최대 10개까지 입력할 수 있습니다.';
    }
    if (tags.any((String tag) => tag.length > 30)) {
      return '검색 키워드는 각각 30자 이하여야 합니다.';
    }
    return null;
  }

  String? _requiredValidator(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) {
      return null;
    }
    final List<String> parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  String _toApiTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
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
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
