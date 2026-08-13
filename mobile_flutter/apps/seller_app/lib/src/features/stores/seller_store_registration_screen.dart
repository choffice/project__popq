import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'business_registration_ocr_service.dart';
import 'seller_business_schedule.dart';
import 'seller_store_location_picker_screen.dart';
import 'seller_local_file_image_io.dart'
    if (dart.library.html) 'seller_local_file_image_web.dart';
import 'seller_phone_input.dart';
import 'seller_store_repository.dart';
import 'seller_store_selection_controller.dart';
import 'seller_tag_editor.dart';
import '../auth/seller_identity_repository.dart';
import 'package:geolocator/geolocator.dart';

enum _ImportedValueChoice {
  current,
  imported,
  manual,
}

class _ImportedStoreInformation {
  const _ImportedStoreInformation({
    required this.sourceLabel,
    this.name,
    this.address,
    this.phone,
  });

  final String sourceLabel;
  final String? name;
  final String? address;
  final String? phone;
}

class _SelectedStoreLocation {
  const _SelectedStoreLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.sourceLabel,
  });

  final double latitude;
  final double longitude;

  /// 이 좌표를 검색하거나 선택할 때 사용한 주소.
  final String address;

  /// 카카오 업체, 주소 검색, 지도 직접 선택 등.
  final String sourceLabel;
}

class _DeviceLocation {
  const _DeviceLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class SellerStoreRegistrationScreen extends StatefulWidget {
  const SellerStoreRegistrationScreen({
    required this.repository,
    required this.selectionController,
    this.identityRepository,
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStoreSelectionController selectionController;
  final SellerIdentityRepository? identityRepository;

  @override
  State<SellerStoreRegistrationScreen> createState() =>
      _SellerStoreRegistrationScreenState();
}

class _SellerStoreRegistrationScreenState
    extends State<SellerStoreRegistrationScreen> {
  static const List<String> _categories = [
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _addressController =
  TextEditingController();

  final TextEditingController _detailAddressController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  final TextEditingController _descriptionController =
  TextEditingController();

  final TextEditingController _imageUrlController =
  TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedRepresentativeImage;
  Uint8List? _selectedRepresentativeImageBytes;

  bool _pickingRepresentativeImage = false;

  final BusinessRegistrationOcrService
  _businessRegistrationOcrService =
  BusinessRegistrationOcrService();

  bool _recognizingBusinessRegistration = false;

  _SelectedStoreLocation? _selectedStoreLocation;

  bool _searchingAddressLocation = false;

  bool _searchingKakaoPlace = false;

  bool _reverseGeocodingMapLocation = false;

  _DeviceLocation? _currentDeviceLocation;

  bool _loadingCurrentLocation = false;

  String? _currentLocationMessage;

  String _storeType = 'LOCAL_STORE';
  String? _representativeCategory;
  DateTime? _operationStartDate;
  DateTime? _operationEndDate;

  SellerBusinessSchedule _schedule = SellerBusinessSchedule.standard();
  final List<String> _tags = <String>[];

  bool _takeoutAvailable = true;
  bool _dineInAvailable = true;
  bool _orderAcceptingEnabled = true;

  bool _submitting = false;
  bool _registrationCompleted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (Duration _) async {
        await _recoverLostRepresentativeImage();

        if (!mounted) {
          return;
        }

        await _loadCurrentDeviceLocation(
          requestPermission: false,
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_submitting || _registrationCompleted,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('새 사업장 등록'),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode:
          AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: [
              Text(
                '사업장 기본 정보',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                '고객에게 공개될 사업장 정보를 입력해 주세요.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
              const SizedBox(
                height: PopqSpacing.lg,
              ),

              _buildInformationImportCard(context),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              _buildBasicInformationCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildOperationPeriodCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildOperatingHoursCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildOrderPolicyCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildTagCard(context),
              const SizedBox(
                height: PopqSpacing.xl,
              ),
              FilledButton.icon(
                key: const Key(
                  'submit-store-registration',
                ),
                onPressed:
                _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                  dimension: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.add_business_rounded,
                ),
                label: Text(
                  _submitting
                      ? '등록 요청 중...'
                      : '사업장 등록',
                ),
              ),
              const SizedBox(
                height: PopqSpacing.lg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationImportCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '사업장 정보 자동 입력',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '사업자등록증을 촬영하거나 카카오맵에 등록된 업체 정보를 불러올 수 있습니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key(
                  'import-business-registration',
                ),
                onPressed:
                _submitting ||
                    _recognizingBusinessRegistration
                    ? null
                    : _openBusinessRegistrationImport,
                icon: _recognizingBusinessRegistration
                    ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.document_scanner_outlined,
                ),
                label: Text(
                  _recognizingBusinessRegistration
                      ? '사업자등록증 인식 중...'
                      : '사업자등록증으로 자동 입력',
                ),
              ),
            ),

            const SizedBox(
              height: PopqSpacing.sm,
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key(
                  'import-kakao-place',
                ),
                onPressed:
                _submitting ||
                    _searchingKakaoPlace
                    ? null
                    : _openKakaoPlaceImport,
                icon: _searchingKakaoPlace
                    ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.map_outlined,
                ),
                label: Text(
                  _searchingKakaoPlace
                      ? '카카오맵 업체 검색 중...'
                      : '카카오맵 업체 정보 불러오기',
                ),
              ),
            ),

            const SizedBox(
              height: PopqSpacing.sm,
            ),

            Text(
              '불러온 정보는 등록 전에 직접 확인하고 수정할 수 있습니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInformationCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '기본 정보',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            DropdownButtonFormField<String>(
              initialValue: _storeType,
              decoration: const InputDecoration(
                labelText: '사업장 유형',
                prefixIcon: Icon(
                  Icons.category_outlined,
                ),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'LOCAL_STORE',
                  child: Text('일반 매장'),
                ),
                DropdownMenuItem<String>(
                  value: 'EVENT_COMMERCE',
                  child: Text('행사·팝업 판매점'),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _storeType = value;
                });
              },
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            TextFormField(
              key: const Key('store-name'),
              controller: _nameController,
              enabled: !_submitting,
              maxLength: 150,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '사업장명',
                hintText: '예: 서면 포포분식',
                prefixIcon: Icon(
                  Icons.storefront_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '사업장명을 입력해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            DropdownButtonFormField<String>(
              initialValue:
              _representativeCategory,
              decoration: const InputDecoration(
                labelText: '대표 카테고리',
                prefixIcon: Icon(
                  Icons.restaurant_menu_rounded,
                ),
              ),
              items: _categories
                  .map(
                    (String category) =>
                    DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
              )
                  .toList(),
              validator: (String? value) {
                if (value == null ||
                    value.isEmpty) {
                  return '대표 카테고리를 선택해 주세요.';
                }

                return null;
              },
              onChanged: _submitting
                  ? null
                  : (String? value) {
                setState(() {
                  _representativeCategory =
                      value;
                });
              },
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            TextFormField(
              controller: _addressController,
              enabled: !_submitting,
              maxLength: 255,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '주소',
                hintText:
                '예: 부산광역시 부산진구 중앙대로 123',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '주소를 입력해 주세요.';
                }

                return null;
              },
              onChanged: (String value) {
                final _SelectedStoreLocation?
                selectedLocation =
                    _selectedStoreLocation;

                if (selectedLocation == null) {
                  return;
                }

                final bool stillMatches =
                    _normalizeComparisonText(
                      value,
                    ) ==
                        _normalizeComparisonText(
                          selectedLocation.address,
                        );

                if (stillMatches) {
                  return;
                }

                setState(() {
                  _selectedStoreLocation = null;
                });
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextFormField(
              controller:
              _detailAddressController,
              enabled: !_submitting,
              maxLength: 255,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '상세 주소',
                hintText:
                '예: 포포빌딩 1층 101호',
                prefixIcon: Icon(
                  Icons.maps_home_work_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '상세 주소를 입력해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),

            _buildStoreLocationSection(context),

            const SizedBox(
              height: PopqSpacing.md,
            ),
            SellerPhoneInput(
              controller: _phoneController,
              enabled: !_submitting,
              identityRepository: widget.identityRepository,
              validator: (String? value) {
                final String phone =
                    value?.trim() ?? '';

                if (phone.isEmpty) {
                  return '사업장 연락처를 입력해 주세요.';
                }

                final RegExp validCharacters =
                RegExp(
                  r'^[0-9+\-()\s]+$',
                );

                if (!validCharacters
                    .hasMatch(phone)) {
                  return '연락처 형식을 확인해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextFormField(
              controller:
              _descriptionController,
              enabled: !_submitting,
              maxLength: 1000,
              minLines: 3,
              maxLines: 5,
              textInputAction:
              TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '사업장 설명',
                hintText:
                '사업장의 특징과 주요 판매 상품을 소개해 주세요.',
                alignLabelWithHint: true,
                prefixIcon: Icon(
                  Icons.description_outlined,
                ),
              ),
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            _buildRepresentativeImageSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRepresentativeImageSection(
      BuildContext context,
      ) {
    final XFile? selectedImage =
        _selectedRepresentativeImage;

    final bool imageActionDisabled =
        _submitting ||
            _pickingRepresentativeImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대표 이미지',
          style: Theme.of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Text(
          '카메라로 촬영하거나 갤러리에서 사업장 대표 사진을 선택해 주세요.',
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
        const SizedBox(
          height: PopqSpacing.md,
        ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: selectedImage == null
                ? DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Text(
                      '선택된 대표 사진이 없습니다.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),
            )
                : kIsWeb
                ? Image.memory(
              _selectedRepresentativeImageBytes!,
              width: double.infinity,
              fit: BoxFit.cover,
            )
                : buildSellerLocalFileImage(
              selectedImage.path,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                  ) {
                return const Center(
                  child: Text(
                    '이미지를 표시하지 못했습니다.',
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(
          height: PopqSpacing.md,
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key(
                  'take-representative-image',
                ),
                onPressed: imageActionDisabled
                    ? null
                    : () {
                  _pickRepresentativeImage(
                    ImageSource.camera,
                  );
                },
                icon: const Icon(
                  Icons.photo_camera_outlined,
                ),
                label: const Text(
                  '카메라 촬영',
                ),
              ),
            ),
            const SizedBox(
              width: PopqSpacing.sm,
            ),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key(
                  'select-representative-image',
                ),
                onPressed: imageActionDisabled
                    ? null
                    : () {
                  _pickRepresentativeImage(
                    ImageSource.gallery,
                  );
                },
                icon: const Icon(
                  Icons.photo_library_outlined,
                ),
                label: const Text(
                  '갤러리 선택',
                ),
              ),
            ),
          ],
        ),
        if (_pickingRepresentativeImage) ...[
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          const LinearProgressIndicator(),
        ],
        if (selectedImage != null) ...[
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _submitting
                  ? null
                  : _removeRepresentativeImage,
              icon: const Icon(
                Icons.delete_outline_rounded,
              ),
              label: const Text(
                '선택한 사진 제거',
              ),
            ),
          ),
        ],
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Text(
          '선택한 사진은 사업장 등록 시 서버에 업로드됩니다.',
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
        const SizedBox(
          height: PopqSpacing.md,
        ),
        const Divider(),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        TextFormField(
          controller: _imageUrlController,
          enabled: !_submitting,
          maxLength: 1000,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '대표 이미지 URL',
            hintText: 'https://example.com/store.jpg',
            prefixIcon: Icon(
              Icons.link_rounded,
            ),
            helperText:
            '사진을 선택하지 않은 경우에만 이 URL을 사용합니다.',
          ),
          validator: (String? value) {
            final String imageUrl =
                value?.trim() ?? '';

            if (imageUrl.isEmpty) {
              return null;
            }

            final Uri? uri =
            Uri.tryParse(imageUrl);

            final bool validScheme =
                uri?.scheme == 'http' ||
                    uri?.scheme == 'https';

            if (uri == null ||
                !validScheme ||
                uri.host.isEmpty) {
              return '올바른 이미지 URL을 입력해 주세요.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStoreLocationSection(
      BuildContext context,
      ) {
    final _SelectedStoreLocation? location =
        _selectedStoreLocation;

    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지도 위치',
          style: Theme.of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Text(
          '고객 탐색 지도에 표시할 정확한 사업장 위치를 선택해 주세요.',
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
        const SizedBox(
          height: PopqSpacing.md,
        ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(
            PopqSpacing.md,
          ),
          decoration: BoxDecoration(
            color: location == null
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: location == null
                  ? colorScheme.outlineVariant
                  : colorScheme.primary,
            ),
          ),
          child: location == null
              ? const Row(
            children: [
              Icon(
                Icons.location_off_outlined,
              ),
              SizedBox(
                width: PopqSpacing.sm,
              ),
              Expanded(
                child: Text(
                  '아직 지도 위치가 확정되지 않았습니다.',
                ),
              ),
            ],
          )
              : Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                  ),
                  const SizedBox(
                    width: PopqSpacing.sm,
                  ),
                  Expanded(
                    child: Text(
                      '위치 선택 완료',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                location.address,
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                '위도 ${location.latitude.toStringAsFixed(6)} · '
                    '경도 ${location.longitude.toStringAsFixed(6)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                '선택 방식: ${location.sourceLabel}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(
          height: PopqSpacing.md,
        ),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key(
              'search-location-by-address',
            ),
            onPressed:
            _submitting ||
                _searchingAddressLocation
                ? null
                : _prepareAddressLocationSearch,
            icon: _searchingAddressLocation
                ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.manage_search_rounded,
            ),
            label: Text(
              _searchingAddressLocation
                  ? '주소 검색 중...'
                  : '입력한 주소로 위치 찾기',
            ),
          ),
        ),

        const SizedBox(
          height: PopqSpacing.sm,
        ),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key(
              'load-current-location',
            ),
            onPressed:
            _submitting ||
                _loadingCurrentLocation
                ? null
                : () {
              _loadCurrentDeviceLocation(
                requestPermission: true,
              );
            },
            icon: _loadingCurrentLocation
                ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.my_location_rounded,
            ),
            label: Text(
              _loadingCurrentLocation
                  ? '현재 위치 확인 중...'
                  : '현재 위치 불러오기',
            ),
          ),
        ),

        if (_currentLocationMessage != null) ...[
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          Text(
            _currentLocationMessage!,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],

        if (_currentDeviceLocation != null) ...[
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          Text(
            '현재 위치: '
                '${_currentDeviceLocation!.latitude.toStringAsFixed(6)}, '
                '${_currentDeviceLocation!.longitude.toStringAsFixed(6)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],

        const SizedBox(
          height: PopqSpacing.sm,
        ),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key(
              'select-location-on-map',
            ),
            onPressed: _submitting
                ? null
                : _prepareMapLocationSelection,
            icon: const Icon(
              Icons.map_outlined,
            ),
            label: const Text(
              '지도에서 직접 위치 선택',
            ),
          ),
        ),

        if (location != null) ...[
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _submitting
                  ? null
                  : _clearSelectedStoreLocation,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                '위치 다시 선택',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOperatingHoursCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '영업 정보',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '야간 영업처럼 종료 시간이 다음 날이어도 등록할 수 있습니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            SellerBusinessScheduleEditor(
              initialSchedule: _schedule,
              enabled: !_submitting,
              onChanged: (value) => setState(() => _schedule = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationPeriodCard(BuildContext context) {
    final bool eventStore = _storeType == 'EVENT_COMMERCE';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eventStore ? '행사 운영 기간' : '영업 시작일',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              eventStore
                  ? '행사 시작일과 종료일을 선택해 주세요.'
                  : '정식 영업 시작일을 선택할 수 있습니다. 종료일은 선택 사항입니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: PopqSpacing.md),
            _operationDateTile(
              label: eventStore ? '행사 시작일' : '영업 시작일',
              value: _operationStartDate,
              onTap: () => _selectOperationDate(start: true),
              onClear: _operationStartDate == null
                  ? null
                  : () => setState(() => _operationStartDate = null),
            ),
            const SizedBox(height: PopqSpacing.sm),
            _operationDateTile(
              label: eventStore ? '행사 종료일' : '영업 종료일(선택)',
              value: _operationEndDate,
              onTap: () => _selectOperationDate(start: false),
              onClear: _operationEndDate == null
                  ? null
                  : () => setState(() => _operationEndDate = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _operationDateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback? onClear,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(value == null ? '선택 안 함' : _formatDate(value)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onClear != null)
            IconButton(
              tooltip: '날짜 지우기',
              onPressed: _submitting ? null : onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            tooltip: '날짜 선택',
            onPressed: _submitting ? null : onTap,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _selectOperationDate({required bool start}) async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime first = DateTime(today.year - 10);
    final DateTime last = DateTime(today.year + 20);
    final DateTime candidate = start
        ? (_operationStartDate ?? today)
        : (_operationEndDate ?? _operationStartDate ?? today);
    final DateTime initial = candidate.isBefore(first)
        ? first
        : candidate.isAfter(last)
            ? last
            : candidate;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _operationStartDate = DateUtils.dateOnly(selected);
      } else {
        _operationEndDate = DateUtils.dateOnly(selected);
      }
    });
  }

  String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}.$month.$day';
  }

  Widget _buildOrderPolicyCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '주문 운영 설정',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            SwitchListTile(
              contentPadding:
              EdgeInsets.zero,
              title: const Text('포장 가능'),
              subtitle: const Text(
                '고객이 포장 주문을 선택할 수 있습니다.',
              ),
              value: _takeoutAvailable,
              onChanged: _submitting
                  ? null
                  : (bool value) {
                setState(() {
                  _takeoutAvailable =
                      value;
                });
              },
            ),
            SwitchListTile(
              contentPadding:
              EdgeInsets.zero,
              title:
              const Text('매장 식사 가능'),
              subtitle: const Text(
                '고객이 매장 식사를 선택할 수 있습니다.',
              ),
              value: _dineInAvailable,
              onChanged: _submitting
                  ? null
                  : (bool value) {
                setState(() {
                  _dineInAvailable =
                      value;
                });
              },
            ),
            SwitchListTile(
              contentPadding:
              EdgeInsets.zero,
              title:
              const Text('주문 접수 가능'),
              subtitle: const Text(
                '등록 직후 주문을 받을 수 있도록 설정합니다.',
              ),
              value:
              _orderAcceptingEnabled,
              onChanged: _submitting
                  ? null
                  : (bool value) {
                setState(() {
                  _orderAcceptingEnabled =
                      value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: SellerTagBlocks(
          title: '검색 키워드',
          description: '고객이 사업장을 찾기 쉽도록 최대 8개까지 등록할 수 있습니다.',
          tags: _tags,
          maxCount: 8,
          enabled: !_submitting,
          onAdd: _addTag,
          onDeleted: (tag) => setState(() => _tags.remove(tag)),
        ),
      ),
    );
  }

  Future<void> _openBusinessRegistrationImport() async {
    if (_submitting ||
        _recognizingBusinessRegistration) {
      return;
    }

    final ImageSource? source =
    await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (
          BuildContext bottomSheetContext,
          ) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                  ),
                  title: const Text(
                    '사업자등록증 촬영',
                  ),
                  subtitle: const Text(
                    '카메라로 등록증을 촬영합니다.',
                  ),
                  onTap: () {
                    Navigator.of(
                      bottomSheetContext,
                    ).pop(
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text(
                    '갤러리에서 선택',
                  ),
                  subtitle: const Text(
                    '저장된 등록증 사진을 선택합니다.',
                  ),
                  onTap: () {
                    Navigator.of(
                      bottomSheetContext,
                    ).pop(
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(
                  height: PopqSpacing.sm,
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(
                        bottomSheetContext,
                      ).pop();
                    },
                    child: const Text('취소'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    await _recognizeBusinessRegistration(
      source,
    );
  }

  Future<void> _recognizeBusinessRegistration(
      ImageSource source,
      ) async {
    setState(() {
      _recognizingBusinessRegistration = true;
    });

    try {
      final XFile? selectedImage =
      await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
        requestFullMetadata: false,
      );

      if (selectedImage == null) {
        return;
      }

      final BusinessRegistrationOcrResult result =
      await _businessRegistrationOcrService
          .recognize(
        imagePath: selectedImage.path,
      );

      if (!mounted) {
        return;
      }

      final bool applyToForm =
      await _showBusinessRegistrationOcrResult(
        result,
      );

      if (!mounted || !applyToForm) {
        return;
      }

      final bool hasImportedFormValue =
          result.businessName != null ||
              result.businessAddress != null;

      if (!hasImportedFormValue) {
        _showMessage(
          '사업자등록번호는 확인했지만 상호명과 주소를 자동으로 찾지 못했습니다. 직접 입력해 주세요.',
        );
        return;
      }

      await _applyImportedInformation(
        _ImportedStoreInformation(
          sourceLabel: '사업자등록증 OCR',
          name: result.businessName,
          address: result.businessAddress,
          phone: null,
        ),
      );
    } on BusinessRegistrationOcrException catch (
    exception
    ) {
      if (!mounted) {
        return;
      }

      _showMessage(
        exception.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '사업자등록증을 인식하는 중 오류가 발생했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _recognizingBusinessRegistration = false;
        });
      }
    }
  }

  Future<bool>
  _showBusinessRegistrationOcrResult(
      BusinessRegistrationOcrResult result,
      ) async {
    final bool hasImportableValue =
        result.businessName != null ||
            result.businessAddress != null;

    final bool? applyToForm =
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title: const Text(
            '사업자등록증 인식 결과',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildOcrResultItem(
                    context: context,
                    label: '사업자등록번호',
                    value: result.businessNumber,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  _buildOcrResultItem(
                    context: context,
                    label: '상호명',
                    value: result.businessName,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  _buildOcrResultItem(
                    context: context,
                    label: '대표자명',
                    value:
                    result.representativeName,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  _buildOcrResultItem(
                    context: context,
                    label: '사업장 소재지',
                    value:
                    result.businessAddress,
                  ),
                  const SizedBox(
                    height: PopqSpacing.lg,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      PopqSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                      BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '사업자등록번호와 대표자명은 확인용이며 '
                          '현재 사업장 DB에는 저장하지 않습니다.',
                    ),
                  ),
                  const SizedBox(
                    height: PopqSpacing.lg,
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding:
                    const EdgeInsets.only(
                      bottom: PopqSpacing.sm,
                    ),
                    title: const Text(
                      'OCR 전체 원문 보기',
                    ),
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding:
                          const EdgeInsets.all(
                            PopqSpacing.sm,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: SelectableText(
                              result.rawText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                '취소',
              ),
            ),
            FilledButton(
              onPressed: hasImportableValue
                  ? () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              }
                  : null,
              child: const Text(
                '입력폼에 반영',
              ),
            ),
          ],
        );
      },
    );

    return applyToForm ?? false;
  }

  Widget _buildOcrResultItem({
    required BuildContext context,
    required String label,
    required String? value,
  }) {
    final String displayedValue =
    value?.trim().isNotEmpty == true
        ? value!.trim()
        : '인식하지 못함';

    final bool recognized =
        value?.trim().isNotEmpty == true;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge,
        ),
        const SizedBox(
          height: PopqSpacing.xs,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(
            PopqSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: recognized
                  ? Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  : Theme.of(context)
                  .colorScheme
                  .error,
            ),
            borderRadius:
            BorderRadius.circular(8),
          ),
          child: SelectableText(
            displayedValue,
            style: TextStyle(
              color: recognized
                  ? null
                  : Theme.of(context)
                  .colorScheme
                  .error,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openKakaoPlaceImport() async {
    if (_submitting ||
        _searchingKakaoPlace) {
      return;
    }

    final String? query =
    await _showKakaoPlaceSearchQueryDialog();

    if (!mounted ||
        query == null ||
        query.trim().isEmpty) {
      return;
    }

    setState(() {
      _searchingKakaoPlace = true;
    });

    try {
      final List<SellerKakaoPlaceSearchResult>
      results =
      await widget.repository.searchPlaces(
        query,
      );

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        _showMessage(
          '카카오맵에서 업체를 찾지 못했습니다. '
              '지역명과 업체명을 함께 입력해 다시 검색해 주세요.',
        );
        return;
      }

      final SellerKakaoPlaceSearchResult?
      selectedPlace =
      await _showKakaoPlaceSearchResultDialog(
        results,
      );

      if (!mounted ||
          selectedPlace == null) {
        return;
      }

      await _applySelectedKakaoPlace(
        selectedPlace,
      );
    } on PopqFailure catch (failure) {
      if (!mounted) {
        return;
      }

      _showMessage(
        failure.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '카카오맵 업체를 검색하는 중 오류가 발생했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _searchingKakaoPlace = false;
        });
      }
    }
  }

  Future<String?>
  _showKakaoPlaceSearchQueryDialog() async {
    final String currentName =
    _nameController.text.trim();

    final String currentAddress =
    _addressController.text.trim();

    final String initialQuery =
    <String>[
      currentAddress,
      currentName,
    ].where(
          (String value) => value.isNotEmpty,
    ).join(' ');

    String queryValue = initialQuery;
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (
          BuildContext dialogContext,
          ) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            void submitSearch() {
              final String trimmed =
              queryValue.trim();

              if (trimmed.isEmpty) {
                setDialogState(() {
                  errorText =
                  '검색할 업체명이나 지역을 입력해 주세요.';
                });
                return;
              }

              FocusScope.of(
                dialogContext,
              ).unfocus();

              Navigator.of(
                dialogContext,
              ).pop(trimmed);
            }

            return AlertDialog(
              title: const Text(
                '카카오맵 업체 검색',
              ),
              content: TextFormField(
                initialValue: initialQuery,
                autofocus: true,
                textInputAction:
                TextInputAction.search,
                decoration: InputDecoration(
                  labelText: '업체명 또는 검색어',
                  hintText:
                  '예: 부산 서면 포포카페',
                  errorText: errorText,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                ),
                onChanged: (String value) {
                  queryValue = value;

                  if (errorText != null &&
                      value.trim().isNotEmpty) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
                onFieldSubmitted: (
                    String value,
                    ) {
                  queryValue = value;
                  submitSearch();
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(
                      dialogContext,
                    ).unfocus();

                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    '취소',
                  ),
                ),
                FilledButton(
                  onPressed: submitSearch,
                  child: const Text(
                    '검색',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<SellerKakaoPlaceSearchResult?>
  _showKakaoPlaceSearchResultDialog(
      List<SellerKakaoPlaceSearchResult>
      results,
      ) {
    SellerKakaoPlaceSearchResult
    selectedPlace = results.first;

    return showDialog<
        SellerKakaoPlaceSearchResult>(
      context: context,
      barrierDismissible: false,
      builder: (
          BuildContext dialogContext,
          ) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                '카카오맵 업체 선택',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(
                    maxHeight: 500,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      return const Divider();
                    },
                    itemBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      final SellerKakaoPlaceSearchResult
                      place =
                      results[index];

                      return RadioListTile<
                          SellerKakaoPlaceSearchResult>(
                        contentPadding:
                        EdgeInsets.zero,
                        value: place,
                        groupValue:
                        selectedPlace,
                        onChanged: (
                            SellerKakaoPlaceSearchResult?
                            value,
                            ) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            selectedPlace = value;
                          });
                        },
                        title: Text(
                          place.placeName,
                        ),
                        subtitle: Text(
                          _buildKakaoPlaceSubtitle(
                            place,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    '취소',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop(
                      selectedPlace,
                    );
                  },
                  child: const Text(
                    '이 업체 선택',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _buildKakaoPlaceSubtitle(
      SellerKakaoPlaceSearchResult place,
      ) {
    final List<String> lines =
    <String>[];

    final String? category =
        place.categoryName;

    final String? phone =
        place.phone;

    final String? roadAddress =
        place.roadAddressName;

    final String? jibunAddress =
        place.addressName;

    if (category != null &&
        category.isNotEmpty) {
      lines.add(category);
    }

    if (roadAddress != null &&
        roadAddress.isNotEmpty) {
      lines.add(
        '도로명: $roadAddress',
      );
    }

    if (jibunAddress != null &&
        jibunAddress.isNotEmpty &&
        jibunAddress != roadAddress) {
      lines.add(
        '지번: $jibunAddress',
      );
    }

    if (phone != null &&
        phone.isNotEmpty) {
      lines.add(
        '전화: $phone',
      );
    }

    lines.add(
      '위도 ${place.latitude.toStringAsFixed(6)} · '
          '경도 ${place.longitude.toStringAsFixed(6)}',
    );

    return lines.join('\n');
  }

  Future<void> _applySelectedKakaoPlace(
      SellerKakaoPlaceSearchResult place,
      ) async {
    final String importedAddress =
    place.displayAddress.trim();

    final String resolvedName =
    await _resolveImportedText(
      fieldLabel: '사업장명',
      sourceLabel: '카카오맵',
      currentValue:
      _nameController.text,
      importedValue:
      place.placeName,
    );

    if (!mounted) {
      return;
    }

    final String resolvedAddress =
    await _resolveImportedText(
      fieldLabel: '주소',
      sourceLabel: '카카오맵',
      currentValue:
      _addressController.text,
      importedValue:
      importedAddress,
    );

    if (!mounted) {
      return;
    }

    final String resolvedPhone =
    await _resolveImportedText(
      fieldLabel: '사업장 연락처',
      sourceLabel: '카카오맵',
      currentValue:
      _phoneController.text,
      importedValue:
      place.phone,
    );

    if (!mounted) {
      return;
    }

    final String normalizedResolvedAddress =
    _normalizeComparisonText(
      resolvedAddress,
    );

    final Set<String> placeAddresses =
    <String>{
      if (place.roadAddressName != null &&
          place.roadAddressName!
              .trim()
              .isNotEmpty)
        _normalizeComparisonText(
          place.roadAddressName!,
        ),
      if (place.addressName != null &&
          place.addressName!
              .trim()
              .isNotEmpty)
        _normalizeComparisonText(
          place.addressName!,
        ),
    };

    final bool addressMatchesPlace =
    placeAddresses.contains(
      normalizedResolvedAddress,
    );

    setState(() {
      _nameController.text =
          resolvedName;

      _addressController.text =
          resolvedAddress;

      _phoneController.text =
          resolvedPhone;

      _selectedStoreLocation =
      addressMatchesPlace
          ? _SelectedStoreLocation(
        latitude:
        place.latitude,
        longitude:
        place.longitude,
        address:
        resolvedAddress,
        sourceLabel:
        '카카오 업체 검색',
      )
          : null;
    });

    if (!addressMatchesPlace) {
      _showMessage(
        '업체 정보는 반영했지만 선택한 주소가 '
            '카카오 업체 주소와 달라 지도 위치를 저장하지 않았습니다. '
            '주소 검색이나 지도 직접 선택으로 위치를 확인해 주세요.',
      );
      return;
    }

    _showMessage(
      '카카오맵 업체 정보와 위치를 입력폼에 반영했습니다.',
    );
  }

  Future<void> _applyImportedInformation(
      _ImportedStoreInformation information,
      ) async {
    if (_submitting) {
      return;
    }

    final String resolvedName = await _resolveImportedText(
      fieldLabel: '사업장명',
      sourceLabel: information.sourceLabel,
      currentValue: _nameController.text,
      importedValue: information.name,
    );

    if (!mounted) {
      return;
    }

    final String resolvedAddress = await _resolveImportedText(
      fieldLabel: '주소',
      sourceLabel: information.sourceLabel,
      currentValue: _addressController.text,
      importedValue: information.address,
    );

    if (!mounted) {
      return;
    }

    final String resolvedPhone = await _resolveImportedText(
      fieldLabel: '사업장 연락처',
      sourceLabel: information.sourceLabel,
      currentValue: _phoneController.text,
      importedValue: information.phone,
    );

    if (!mounted) {
      return;
    }

    final _SelectedStoreLocation?
    previousLocation =
        _selectedStoreLocation;

    final bool locationAddressChanged =
        previousLocation != null &&
            _normalizeComparisonText(
              previousLocation.address,
            ) !=
                _normalizeComparisonText(
                  resolvedAddress,
                );

    setState(() {
      _nameController.text =
          resolvedName;

      _addressController.text =
          resolvedAddress;

      _phoneController.text =
          resolvedPhone;

      if (locationAddressChanged) {
        _selectedStoreLocation = null;
      }
    });

    _showMessage(
      locationAddressChanged
          ? '${information.sourceLabel} 정보를 반영했습니다. '
          '주소가 변경되어 지도 위치를 다시 선택해 주세요.'
          : '${information.sourceLabel} 정보를 입력폼에 반영했습니다.',
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

    // 불러온 값이 없으면 기존 값을 그대로 둔다.
    if (imported.isEmpty) {
      return current;
    }

    // 사용자가 아직 입력하지 않았다면 바로 자동 입력한다.
    if (current.isEmpty) {
      return imported;
    }

    // 공백과 대소문자 차이만 있다면 같은 값으로 처리한다.
    if (_normalizeComparisonText(current) ==
        _normalizeComparisonText(imported)) {
      return current;
    }

    return _showImportedValueConflictDialog(
      fieldLabel: fieldLabel,
      sourceLabel: sourceLabel,
      currentValue: current,
      importedValue: imported,
    );
  }

  String _normalizeComparisonText(
      String value,
      ) {
    return value
        .replaceAll(
      RegExp(r'\s+'),
      '',
    )
        .toLowerCase();
  }

  Future<String> _showImportedValueConflictDialog({
    required String fieldLabel,
    required String sourceLabel,
    required String currentValue,
    required String importedValue,
  }) async {
    final TextEditingController manualController =
    TextEditingController(
      text: currentValue,
    );

    _ImportedValueChoice selectedChoice =
        _ImportedValueChoice.current;

    String? manualInputError;

    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            return AlertDialog(
              title: Text(
                '$fieldLabel 정보 확인',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sourceLabel에서 불러온 정보가 현재 입력한 내용과 다릅니다.',
                    ),
                    const SizedBox(
                      height: PopqSpacing.md,
                    ),

                    RadioListTile<_ImportedValueChoice>(
                      contentPadding: EdgeInsets.zero,
                      value:
                      _ImportedValueChoice.current,
                      groupValue: selectedChoice,
                      title: const Text(
                        '현재 입력 유지',
                      ),
                      subtitle: Text(
                        currentValue,
                      ),
                      onChanged: (
                          _ImportedValueChoice? value,
                          ) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedChoice = value;
                          manualInputError = null;
                        });
                      },
                    ),

                    RadioListTile<_ImportedValueChoice>(
                      contentPadding: EdgeInsets.zero,
                      value:
                      _ImportedValueChoice.imported,
                      groupValue: selectedChoice,
                      title: Text(
                        '$sourceLabel 정보 사용',
                      ),
                      subtitle: Text(
                        importedValue,
                      ),
                      onChanged: (
                          _ImportedValueChoice? value,
                          ) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedChoice = value;
                          manualInputError = null;
                        });
                      },
                    ),

                    RadioListTile<_ImportedValueChoice>(
                      contentPadding: EdgeInsets.zero,
                      value:
                      _ImportedValueChoice.manual,
                      groupValue: selectedChoice,
                      title: const Text(
                        '직접 입력',
                      ),
                      onChanged: (
                          _ImportedValueChoice? value,
                          ) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedChoice = value;
                          manualInputError = null;
                        });
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.only(
                        left: PopqSpacing.md,
                      ),
                      child: TextField(
                        controller: manualController,
                        enabled: selectedChoice ==
                            _ImportedValueChoice.manual,
                        decoration: InputDecoration(
                          labelText: '$fieldLabel 직접 입력',
                          errorText: manualInputError,
                        ),
                        onTap: () {
                          if (selectedChoice !=
                              _ImportedValueChoice.manual) {
                            setDialogState(() {
                              selectedChoice =
                                  _ImportedValueChoice
                                      .manual;
                              manualInputError = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      currentValue,
                    );
                  },
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedChoice ==
                        _ImportedValueChoice.current) {
                      Navigator.of(dialogContext).pop(
                        currentValue,
                      );
                      return;
                    }

                    if (selectedChoice ==
                        _ImportedValueChoice.imported) {
                      Navigator.of(dialogContext).pop(
                        importedValue,
                      );
                      return;
                    }

                    final String manualValue =
                    manualController.text.trim();

                    if (manualValue.isEmpty) {
                      setDialogState(() {
                        manualInputError =
                        '$fieldLabel을 입력해 주세요.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      manualValue,
                    );
                  },
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? currentValue;
  }

  Future<void> _pickRepresentativeImage(
      ImageSource source,
      ) async {
    if (_submitting ||
        _pickingRepresentativeImage) {
      return;
    }

    setState(() {
      _pickingRepresentativeImage = true;
    });

    try {
      final XFile? selectedImage =
      await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (!mounted) {
        return;
      }

      if (selectedImage == null) {
        setState(() {
          _pickingRepresentativeImage = false;
        });

        return;
      }

      final Uint8List? selectedImageBytes =
      kIsWeb ? await selectedImage.readAsBytes() : null;

      setState(() {
        _selectedRepresentativeImage =
            selectedImage;
        _selectedRepresentativeImageBytes =
            selectedImageBytes;

        _pickingRepresentativeImage = false;
      });

      _showMessage(
        source == ImageSource.camera
            ? '촬영한 사진을 대표 이미지로 선택했습니다.'
            : '갤러리 사진을 대표 이미지로 선택했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pickingRepresentativeImage = false;
      });

      _showMessage(
        source == ImageSource.camera
            ? '카메라를 실행하지 못했습니다.'
            : '갤러리에서 사진을 불러오지 못했습니다.',
      );
    }
  }

  void _removeRepresentativeImage() {
    if (_submitting) {
      return;
    }

    setState(() {
      _selectedRepresentativeImage = null;
      _selectedRepresentativeImageBytes = null;
    });

    _showMessage(
      '선택한 대표 사진을 제거했습니다.',
    );
  }

  Future<void>
  _prepareAddressLocationSearch() async {
    if (_submitting ||
        _searchingAddressLocation) {
      return;
    }

    final String address =
    _addressController.text.trim();

    if (address.isEmpty) {
      _showMessage(
        '위치를 검색할 주소를 먼저 입력해 주세요.',
      );
      return;
    }

    setState(() {
      _searchingAddressLocation = true;
    });

    try {
      final List<SellerAddressSearchResult>
      results =
      await widget.repository
          .searchAddresses(
        address,
      );

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        _showMessage(
          '입력한 주소의 검색 결과를 찾지 못했습니다. '
              '상세 주소를 제외하고 도로명이나 지번 주소로 다시 검색해 주세요.',
        );
        return;
      }

      final SellerAddressSearchResult?
      selectedResult =
      await _showAddressSearchResultDialog(
        results,
      );

      if (!mounted ||
          selectedResult == null) {
        return;
      }

      await _applySelectedStoreLocation(
        sourceLabel: '카카오 주소 검색',
        address:
        selectedResult.addressName,
        latitude:
        selectedResult.latitude,
        longitude:
        selectedResult.longitude,
      );
    } on PopqFailure catch (failure) {
      if (!mounted) {
        return;
      }

      _showMessage(
        failure.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '주소를 검색하는 중 오류가 발생했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _searchingAddressLocation =
          false;
        });
      }
    }
  }

  Future<SellerAddressSearchResult?>
  _showAddressSearchResultDialog(
      List<SellerAddressSearchResult> results,
      ) {
    SellerAddressSearchResult
    selectedResult = results.first;

    return showDialog<
        SellerAddressSearchResult>(
      context: context,
      barrierDismissible: false,
      builder: (
          BuildContext dialogContext,
          ) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                '사업장 위치 선택',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(
                    maxHeight: 460,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      return const Divider();
                    },
                    itemBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      final SellerAddressSearchResult
                      result =
                      results[index];

                      return RadioListTile<
                          SellerAddressSearchResult>(
                        contentPadding:
                        EdgeInsets.zero,
                        value: result,
                        groupValue:
                        selectedResult,
                        onChanged: (
                            SellerAddressSearchResult?
                            value,
                            ) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            selectedResult = value;
                          });
                        },
                        title: Text(
                          result.addressName,
                        ),
                        subtitle: Text(
                          _buildAddressSearchSubtitle(
                            result,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    '취소',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop(
                      selectedResult,
                    );
                  },
                  child: const Text(
                    '이 위치 선택',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _buildAddressSearchSubtitle(
      SellerAddressSearchResult result,
      ) {
    final List<String> lines =
    <String>[];

    final String? roadAddress =
        result.roadAddressName;

    final String? jibunAddress =
        result.jibunAddressName;

    if (roadAddress != null &&
        roadAddress.isNotEmpty &&
        roadAddress !=
            result.addressName) {
      lines.add(
        '도로명: $roadAddress',
      );
    }

    if (jibunAddress != null &&
        jibunAddress.isNotEmpty &&
        jibunAddress !=
            result.addressName) {
      lines.add(
        '지번: $jibunAddress',
      );
    }

    if (result.zoneNo != null) {
      lines.add(
        '우편번호: ${result.zoneNo}',
      );
    }

    lines.add(
      '위도 ${result.latitude.toStringAsFixed(6)} · '
          '경도 ${result.longitude.toStringAsFixed(6)}',
    );

    return lines.join('\n');
  }

  Future<void> _loadCurrentDeviceLocation({
    required bool requestPermission,
  }) async {
    if (_loadingCurrentLocation) {
      return;
    }

    setState(() {
      _loadingCurrentLocation = true;
      _currentLocationMessage = null;
    });

    try {
      final bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentLocationMessage =
          '기기의 위치 서비스가 꺼져 있습니다.';
        });

        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied &&
          requestPermission) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentLocationMessage =
          '현재 위치를 사용하려면 위치 권한을 허용해 주세요.';
        });

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentLocationMessage =
          '위치 권한이 영구적으로 거부되었습니다. '
              '앱 설정에서 위치 권한을 허용해 주세요.';
        });

        return;
      }

      Position? position =
      await Geolocator.getLastKnownPosition();

      position ??=
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(
            seconds: 12,
          ),
        ),
      );
      final Position resolvedPosition = position;

      if (!mounted) {
        return;
      }

      if (requestPermission) {
        final SellerReverseGeocodeResult result =
        await widget.repository.reverseGeocode(
          latitude: resolvedPosition.latitude,
          longitude: resolvedPosition.longitude,
        );
        if (!mounted) return;

        final String currentAddress = _addressController.text.trim();
        final String resolvedAddress = result.displayAddress.trim();
        bool applyAddress = currentAddress.isEmpty ||
            _normalizeComparisonText(currentAddress) ==
                _normalizeComparisonText(resolvedAddress) ||
            result.addressCandidates.any(
              (String candidate) =>
                  _normalizeComparisonText(candidate) ==
                  _normalizeComparisonText(currentAddress),
            );

        if (!applyAddress) {
          applyAddress = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) => AlertDialog(
                  title: const Text('현재 위치 주소 적용'),
                  content: Text(
                    '기존 주소\n$currentAddress\n\n현재 위치 주소\n$resolvedAddress\n\n'
                    '현재 위치 주소와 좌표로 변경할까요?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('기존 주소 유지'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('현재 위치 적용'),
                    ),
                  ],
                ),
              ) ??
              false;
        }

        if (applyAddress && mounted) {
          setState(() {
            _addressController.text = resolvedAddress;
            _selectedStoreLocation = _SelectedStoreLocation(
              latitude: resolvedPosition.latitude,
              longitude: resolvedPosition.longitude,
              address: resolvedAddress,
              sourceLabel: '현재 위치',
            );
          });
        }
      }

      setState(() {
        _currentDeviceLocation =
            _DeviceLocation(
              latitude: resolvedPosition.latitude,
              longitude: resolvedPosition.longitude,
            );

        _currentLocationMessage =
        '현재 위치를 지도 시작점으로 준비했습니다.';
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocationMessage =
        '현재 위치를 확인하는 데 시간이 오래 걸리고 있습니다.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocationMessage =
        '현재 위치를 확인하지 못했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCurrentLocation = false;
        });
      }
    }
  }

  Future<void>
  _prepareMapLocationSelection() async {
    if (_submitting) {
      return;
    }

    final String address =
    _addressController.text.trim();

    if (address.isEmpty) {
      _showMessage(
        '지도 위치를 선택하기 전에 '
            '사업장 주소를 먼저 입력해 주세요.',
      );
      return;
    }

    final _SelectedStoreLocation?
    selectedLocation =
        _selectedStoreLocation;

    final _DeviceLocation?
    currentLocation =
        _currentDeviceLocation;

    const double busanLatitude =
    35.157746;

    const double busanLongitude =
    129.059319;

    /*
   * 시작 중심 우선순위:
   *
   * 1. 이전에 선택한 사업장 좌표
   * 2. 기기 현재 위치
   * 3. 부산 서면역
   */
    final double initialLatitude =
        selectedLocation?.latitude ??
            currentLocation?.latitude ??
            busanLatitude;

    final double initialLongitude =
        selectedLocation?.longitude ??
            currentLocation?.longitude ??
            busanLongitude;

    final SellerMapLocationPickResult?
    result =
    await Navigator.of(context).push<
        SellerMapLocationPickResult>(
      MaterialPageRoute<
          SellerMapLocationPickResult>(
        builder: (
            BuildContext context,
            ) {
          return SellerStoreLocationPickerScreen(
            initialLatitude:
            initialLatitude,
            initialLongitude:
            initialLongitude,
            currentLatitude:
            currentLocation?.latitude,
            currentLongitude:
            currentLocation?.longitude,
            addressLabel: address,
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _reverseGeocodingMapLocation =
      true;
    });

    try {
      final SellerReverseGeocodeResult
      reverseResult =
      await widget.repository
          .reverseGeocode(
        latitude: result.latitude,
        longitude: result.longitude,
      );

      if (!mounted) {
        return;
      }

      await _applyReverseGeocodedMapLocation(
        reverseResult,
      );
    } on PopqFailure catch (failure) {
      if (!mounted) {
        return;
      }

      _showMessage(
        failure.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '선택한 지도 위치의 주소를 확인하지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _reverseGeocodingMapLocation =
          false;
        });
      }
    }
  }

  Future<void>
  _applyReverseGeocodedMapLocation(
      SellerReverseGeocodeResult result,
      ) async {
    final String currentAddress =
    _addressController.text.trim();

    final String mapAddress =
    result.displayAddress.trim();

    if (mapAddress.isEmpty) {
      _showMessage(
        '지도에서 선택한 위치의 주소를 확인하지 못했습니다.',
      );
      return;
    }

    final Set<String> normalizedCandidates =
    result.addressCandidates
        .map(
      _normalizeComparisonText,
    )
        .toSet();

    /*
   * 기존 주소가 비어 있으면 지도 주소와 좌표를
   * 그대로 적용한다.
   */
    if (currentAddress.isEmpty) {
      setState(() {
        _addressController.text =
            mapAddress;

        _selectedStoreLocation =
            _SelectedStoreLocation(
              latitude: result.latitude,
              longitude: result.longitude,
              address: mapAddress,
              sourceLabel: '지도 직접 선택',
            );
      });

      _showMessage(
        '지도에서 선택한 주소와 위치를 적용했습니다.',
      );

      return;
    }

    final bool currentAddressMatches =
    normalizedCandidates.contains(
      _normalizeComparisonText(
        currentAddress,
      ),
    );

    /*
   * 도로명 또는 지번 주소가 기존 주소와 같다면
   * 주소는 유지하고 좌표만 적용한다.
   */
    if (currentAddressMatches) {
      setState(() {
        _selectedStoreLocation =
            _SelectedStoreLocation(
              latitude: result.latitude,
              longitude: result.longitude,
              address: currentAddress,
              sourceLabel: '지도 직접 선택',
            );
      });

      _showMessage(
        '입력한 주소와 지도 위치가 일치합니다.',
      );

      return;
    }

    /*
   * 주소가 다르면 기존에 만든 충돌 모달을 사용한다.
   */
    final String resolvedAddress =
    await _showImportedValueConflictDialog(
      fieldLabel: '주소',
      sourceLabel: '지도에서 선택한 위치',
      currentValue: currentAddress,
      importedValue: mapAddress,
    );

    if (!mounted) {
      return;
    }

    final bool resolvedMatchesMap =
    normalizedCandidates.contains(
      _normalizeComparisonText(
        resolvedAddress,
      ),
    );

    setState(() {
      _addressController.text =
          resolvedAddress;

      /*
     * 지도 주소를 선택했거나 직접 입력값이
     * 카카오 주소와 같을 때만 좌표를 확정한다.
     *
     * 기존의 다른 주소를 유지했다면 좌표는 저장하지 않는다.
     */
      _selectedStoreLocation =
      resolvedMatchesMap
          ? _SelectedStoreLocation(
        latitude:
        result.latitude,
        longitude:
        result.longitude,
        address:
        resolvedAddress,
        sourceLabel:
        '지도 직접 선택',
      )
          : null;
    });

    if (!resolvedMatchesMap) {
      _showMessage(
        '입력 주소를 유지했습니다. '
            '현재 주소에 맞는 지도 위치를 다시 선택해 주세요.',
      );
      return;
    }

    _showMessage(
      '지도에서 선택한 주소와 위치를 적용했습니다.',
    );
  }

  void _clearSelectedStoreLocation() {
    if (_submitting) {
      return;
    }

    setState(() {
      _selectedStoreLocation = null;
    });

    _showMessage(
      '선택된 지도 위치를 초기화했습니다.',
    );
  }

  Future<void> _applySelectedStoreLocation({
    required String sourceLabel,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final String importedAddress =
    address.trim();

    final String previousAddress =
    _addressController.text.trim();

    if (importedAddress.isEmpty) {
      _showMessage(
        '선택한 위치에 주소 정보가 없습니다.',
      );
      return;
    }

    final String resolvedAddress =
    await _resolveImportedText(
      fieldLabel: '주소',
      sourceLabel: sourceLabel,
      currentValue:
      _addressController.text,
      importedValue: importedAddress,
    );

    if (!mounted) {
      return;
    }

    /*
   * 사용자가 카카오 주소 대신 기존 주소나 직접 입력을
   * 선택했다면, 해당 좌표가 실제로 그 주소와 일치하는지
   * 보장할 수 없으므로 좌표를 저장하지 않는다.
   */
    final String normalizedResolved =
    _normalizeComparisonText(
      resolvedAddress,
    );

    final bool addressMatchesLocation =
        normalizedResolved ==
            _normalizeComparisonText(
              importedAddress,
            ) ||
            normalizedResolved ==
                _normalizeComparisonText(
                  previousAddress,
                );

    setState(() {
      _addressController.text =
          resolvedAddress;

      _selectedStoreLocation =
      addressMatchesLocation
          ? _SelectedStoreLocation(
        latitude: latitude,
        longitude: longitude,
        address: importedAddress,
        sourceLabel: sourceLabel,
      )
          : null;
    });

    if (!addressMatchesLocation) {
      _showMessage(
        '주소는 선택한 내용으로 반영했습니다. '
            '지도 위치는 변경된 주소로 다시 확인해 주세요.',
      );
      return;
    }

    _showMessage(
      '$sourceLabel 위치를 적용했습니다.',
    );
  }

  Future<void> _addTag() async {
    if (_submitting) {
      return;
    }

    if (_tags.length >= 8) {
      _showMessage(
        '검색 키워드는 최대 8개까지 등록할 수 있어요.',
      );

      return;
    }

    final String? tag = await showSellerTagInputDialog(
      context,
      existingTags: _tags,
    );
    if (tag != null && mounted) setState(() => _tags.add(tag));
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final bool valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      _showMessage(
        '필수 입력 항목을 확인해 주세요.',
      );

      return;
    }

    final String? scheduleError = _schedule.validationMessage;
    if (scheduleError != null) {
      _showMessage(scheduleError);
      return;
    }

    if (_operationStartDate != null &&
        _operationEndDate != null &&
        _operationEndDate!.isBefore(_operationStartDate!)) {
      _showMessage('운영 종료일은 시작일보다 빠를 수 없습니다.');
      return;
    }

    if (!_takeoutAvailable &&
        !_dineInAvailable) {
      _showMessage(
        '포장 또는 매장 식사 중 하나는 가능해야 해요.',
      );

      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      String? representativeImageUrl =
      _emptyToNull(
        _imageUrlController.text,
      );

      final XFile? selectedImage =
          _selectedRepresentativeImage;

      if (selectedImage != null) {
        _showMessage(
          '대표 사진을 업로드하고 있습니다.',
        );

        representativeImageUrl = kIsWeb
            ? await widget.repository.uploadRepresentativeImageBytes(
                _selectedRepresentativeImageBytes ??
                    await selectedImage.readAsBytes(),
                fileName: selectedImage.name,
              )
            : await widget.repository.uploadRepresentativeImage(
                selectedImage.path,
              );

        if (!mounted) {
          return;
        }

        _imageUrlController.text =
            representativeImageUrl;
      }

      final SellerStore created =
      await widget.repository.create(
        storeType: _storeType,
        name: _nameController.text.trim(),
        description: _emptyToNull(
          _descriptionController.text,
        ),
        address:
        _addressController.text.trim(),
        detailAddress:
        _detailAddressController.text
            .trim(),
        representativeCategory:
        _representativeCategory,
        imageUrl: representativeImageUrl,
        phone: _phoneController.text.trim(),

        latitude:
        _selectedStoreLocation?.latitude,

        longitude:
        _selectedStoreLocation?.longitude,

        openTime: _schedule.legacyOpenTimeForApi,
        closeTime: _schedule.legacyCloseTimeForApi,
        operationStartDate: _operationStartDate,
        operationEndDate: _operationEndDate,
        closedDays: _schedule.legacyClosedDays,
        schedule: _schedule,
        takeoutAvailable:
        _takeoutAvailable,
        dineInAvailable:
        _dineInAvailable,
        orderAcceptingEnabled:
        _orderAcceptingEnabled,
        tags: List<String>.unmodifiable(
          _tags,
        ),
      );

      await widget.selectionController
          .select(
        created.storeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _registrationCompleted = true;
      });

      WidgetsBinding.instance
          .addPostFrameCallback(
            (Duration _) {
          if (!mounted) {
            return;
          }

          context.pop<SellerStore>(
            created,
          );
        },
      );
    } on PopqFailure catch (failure) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        failure.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        '사업장을 등록하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  String? _emptyToNull(
      String value,
      ) {
    final String normalized =
    value.trim();

    return normalized.isEmpty
        ? null
        : normalized;
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Future<void> _recoverLostRepresentativeImage() async {
    try {
      final LostDataResponse response =
      await _imagePicker.retrieveLostData();

      if (response.isEmpty || !mounted) {
        return;
      }

      final List<XFile>? files = response.files;

      if (files != null && files.isNotEmpty) {
        final XFile recoveredImage = files.first;
        final Uint8List? recoveredImageBytes =
        kIsWeb ? await recoveredImage.readAsBytes() : null;
        setState(() {
          _selectedRepresentativeImage = recoveredImage;
          _selectedRepresentativeImageBytes = recoveredImageBytes;
        });

        _showMessage(
          '이전에 선택하던 대표 사진을 복구했습니다.',
        );

        return;
      }

      if (response.exception != null) {
        _showMessage(
          '이전에 선택하던 이미지를 복구하지 못했습니다.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '이미지 선택 정보를 복구하지 못했습니다.',
      );
    }
  }
}
