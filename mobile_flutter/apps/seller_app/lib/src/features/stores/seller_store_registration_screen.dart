import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'business_registration_ocr_service.dart';
import 'seller_business_schedule.dart';
import 'seller_store_location_picker_screen.dart';
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

  /// ??醫뚰몴瑜?寃?됲븯嫄곕굹 ?좏깮?????ъ슜??二쇱냼.
  final String address;

  /// 移댁뭅???낆껜, 二쇱냼 寃?? 吏??吏곸젒 ?좏깮 ??
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
          title: const Text('???ъ뾽???깅줉'),
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
                '?ъ뾽??湲곕낯 ?뺣낫',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                '怨좉컼?먭쾶 怨듦컻???ъ뾽???뺣낫瑜??낅젰??二쇱꽭??',
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
                      ? '?깅줉 ?붿껌 以?..'
                      : '?ъ뾽???깅줉',
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
              '?ъ뾽???뺣낫 ?먮룞 ?낅젰',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '?ъ뾽?먮벑濡앹쬆??珥ъ쁺?섍굅??移댁뭅?ㅻ㏊???깅줉???낆껜 ?뺣낫瑜?遺덈윭?????덉뒿?덈떎.',
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
                      ? '?ъ뾽?먮벑濡앹쬆 ?몄떇 以?..'
                      : '?ъ뾽?먮벑濡앹쬆?쇰줈 ?먮룞 ?낅젰',
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
                      ? '移댁뭅?ㅻ㏊ ?낆껜 寃??以?..'
                      : '移댁뭅?ㅻ㏊ ?낆껜 ?뺣낫 遺덈윭?ㅺ린',
                ),
              ),
            ),

            const SizedBox(
              height: PopqSpacing.sm,
            ),

            Text(
              '遺덈윭???뺣낫???깅줉 ?꾩뿉 吏곸젒 ?뺤씤?섍퀬 ?섏젙?????덉뒿?덈떎.',
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
              '湲곕낯 ?뺣낫',
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
                labelText: '?ъ뾽???좏삎',
                prefixIcon: Icon(
                  Icons.category_outlined,
                ),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'LOCAL_STORE',
                  child: Text('?쇰컲 留ㅼ옣'),
                ),
                DropdownMenuItem<String>(
                  value: 'EVENT_COMMERCE',
                  child: Text('?됱궗쨌?앹뾽 ?먮ℓ??),
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
                labelText: '?ъ뾽?λ챸',
                hintText: '?? ?쒕㈃ ?ы룷遺꾩떇',
                prefixIcon: Icon(
                  Icons.storefront_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '?ъ뾽?λ챸???낅젰??二쇱꽭??';
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
                labelText: '???移댄뀒怨좊━',
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
                  return '???移댄뀒怨좊━瑜??좏깮??二쇱꽭??';
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
                labelText: '二쇱냼',
                hintText:
                '?? 遺?곌킅??떆 遺?곗쭊援?以묒븰?濡?123',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '二쇱냼瑜??낅젰??二쇱꽭??';
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
                labelText: '?곸꽭 二쇱냼',
                hintText:
                '?? ?ы룷鍮뚮뵫 1痢?101??,
                prefixIcon: Icon(
                  Icons.maps_home_work_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '?곸꽭 二쇱냼瑜??낅젰??二쇱꽭??';
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
                  return '?ъ뾽???곕씫泥섎? ?낅젰??二쇱꽭??';
                }

                final RegExp validCharacters =
                RegExp(
                  r'^[0-9+\-()\s]+$',
                );

                if (!validCharacters
                    .hasMatch(phone)) {
                  return '?곕씫泥??뺤떇???뺤씤??二쇱꽭??';
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
                labelText: '?ъ뾽???ㅻ챸',
                hintText:
                '?ъ뾽?μ쓽 ?뱀쭠怨?二쇱슂 ?먮ℓ ?곹뭹???뚭컻??二쇱꽭??',
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
          '????대?吏',
          style: Theme.of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Text(
          '移대찓?쇰줈 珥ъ쁺?섍굅??媛ㅻ윭由ъ뿉???ъ뾽??????ъ쭊???좏깮??二쇱꽭??',
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
                      '?좏깮??????ъ쭊???놁뒿?덈떎.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),
            )
                : Image.file(
              File(selectedImage.path),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                  ) {
                return const Center(
                  child: Text(
                    '?대?吏瑜??쒖떆?섏? 紐삵뻽?듬땲??',
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
                  '移대찓??珥ъ쁺',
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
                  '媛ㅻ윭由??좏깮',
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
                '?좏깮???ъ쭊 ?쒓굅',
              ),
            ),
          ),
        ],
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Text(
          '?좏깮???ъ쭊? ?ъ뾽???깅줉 ???쒕쾭???낅줈?쒕맗?덈떎.',
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
            labelText: '????대?吏 URL',
            hintText: 'https://example.com/store.jpg',
            prefixIcon: Icon(
              Icons.link_rounded,
            ),
            helperText:
            '?ъ쭊???좏깮?섏? ?딆? 寃쎌슦?먮쭔 ??URL???ъ슜?⑸땲??',
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
              return '?щ컮瑜??대?吏 URL???낅젰??二쇱꽭??';
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
          '吏???꾩튂',
          style: Theme.of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Text(
          '怨좉컼 ?먯깋 吏?꾩뿉 ?쒖떆???뺥솗???ъ뾽???꾩튂瑜??좏깮??二쇱꽭??',
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
                  '?꾩쭅 吏???꾩튂媛 ?뺤젙?섏? ?딆븯?듬땲??',
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
                      '?꾩튂 ?좏깮 ?꾨즺',
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
                '?꾨룄 ${location.latitude.toStringAsFixed(6)} 쨌 '
                    '寃쎈룄 ${location.longitude.toStringAsFixed(6)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                '?좏깮 諛⑹떇: ${location.sourceLabel}',
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
                  ? '二쇱냼 寃??以?..'
                  : '?낅젰??二쇱냼濡??꾩튂 李얘린',
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
                  ? '?꾩옱 ?꾩튂 ?뺤씤 以?..'
                  : '?꾩옱 ?꾩튂 遺덈윭?ㅺ린',
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
            '?꾩옱 ?꾩튂: '
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
              '吏?꾩뿉??吏곸젒 ?꾩튂 ?좏깮',
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
                '?꾩튂 ?ㅼ떆 ?좏깮',
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
              '?곸뾽 ?뺣낫',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '?쇨컙 ?곸뾽泥섎읆 醫낅즺 ?쒓컙???ㅼ쓬 ?좎씠?대룄 ?깅줉?????덉뒿?덈떎.',
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
              '二쇰Ц ?댁쁺 ?ㅼ젙',
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
              title: const Text('?ъ옣 媛??),
              subtitle: const Text(
                '怨좉컼???ъ옣 二쇰Ц???좏깮?????덉뒿?덈떎.',
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
              const Text('留ㅼ옣 ?앹궗 媛??),
              subtitle: const Text(
                '怨좉컼??留ㅼ옣 ?앹궗瑜??좏깮?????덉뒿?덈떎.',
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
              const Text('二쇰Ц ?묒닔 媛??),
              subtitle: const Text(
                '?깅줉 吏곹썑 二쇰Ц??諛쏆쓣 ???덈룄濡??ㅼ젙?⑸땲??',
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
          title: '寃???ㅼ썙??,
          description: '怨좉컼???ъ뾽?μ쓣 李얘린 ?쎈룄濡?理쒕? 8媛쒓퉴吏 ?깅줉?????덉뒿?덈떎.',
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
                    '?ъ뾽?먮벑濡앹쬆 珥ъ쁺',
                  ),
                  subtitle: const Text(
                    '移대찓?쇰줈 ?깅줉利앹쓣 珥ъ쁺?⑸땲??',
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
                    '媛ㅻ윭由ъ뿉???좏깮',
                  ),
                  subtitle: const Text(
                    '??λ맂 ?깅줉利??ъ쭊???좏깮?⑸땲??',
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
                    child: const Text('痍⑥냼'),
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
          '?ъ뾽?먮벑濡앸쾲?몃뒗 ?뺤씤?덉?留??곹샇紐낃낵 二쇱냼瑜??먮룞?쇰줈 李얠? 紐삵뻽?듬땲?? 吏곸젒 ?낅젰??二쇱꽭??',
        );
        return;
      }

      await _applyImportedInformation(
        _ImportedStoreInformation(
          sourceLabel: '?ъ뾽?먮벑濡앹쬆 OCR',
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
        '?ъ뾽?먮벑濡앹쬆???몄떇?섎뒗 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎.',
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
            '?ъ뾽?먮벑濡앹쬆 ?몄떇 寃곌낵',
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
                    label: '?ъ뾽?먮벑濡앸쾲??,
                    value: result.businessNumber,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  _buildOcrResultItem(
                    context: context,
                    label: '?곹샇紐?,
                    value: result.businessName,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  _buildOcrResultItem(
                    context: context,
                    label: '??쒖옄紐?,
                    value:
                    result.representativeName,
                  ),
                  const SizedBox(
                    height: PopqSpacing.md,
                  ),
                  _buildOcrResultItem(
                    context: context,
                    label: '?ъ뾽???뚯옱吏',
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
                      '?ъ뾽?먮벑濡앸쾲?몄? ??쒖옄紐낆? ?뺤씤?⑹씠硫?'
                          '?꾩옱 ?ъ뾽??DB?먮뒗 ??ν븯吏 ?딆뒿?덈떎.',
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
                      'OCR ?꾩껜 ?먮Ц 蹂닿린',
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
                '痍⑥냼',
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
                '?낅젰?쇱뿉 諛섏쁺',
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
        : '?몄떇?섏? 紐삵븿';

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
          '移댁뭅?ㅻ㏊?먯꽌 ?낆껜瑜?李얠? 紐삵뻽?듬땲?? '
              '吏??챸怨??낆껜紐낆쓣 ?④퍡 ?낅젰???ㅼ떆 寃?됲빐 二쇱꽭??',
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
        '移댁뭅?ㅻ㏊ ?낆껜瑜?寃?됲븯??以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎.',
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
                  '寃?됲븷 ?낆껜紐낆씠??吏??쓣 ?낅젰??二쇱꽭??';
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
                '移댁뭅?ㅻ㏊ ?낆껜 寃??,
              ),
              content: TextFormField(
                initialValue: initialQuery,
                autofocus: true,
                textInputAction:
                TextInputAction.search,
                decoration: InputDecoration(
                  labelText: '?낆껜紐??먮뒗 寃?됱뼱',
                  hintText:
                  '?? 遺???쒕㈃ ?ы룷移댄럹',
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
                    '痍⑥냼',
                  ),
                ),
                FilledButton(
                  onPressed: submitSearch,
                  child: const Text(
                    '寃??,
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
                '移댁뭅?ㅻ㏊ ?낆껜 ?좏깮',
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
                    '痍⑥냼',
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
                    '???낆껜 ?좏깮',
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
        '?꾨줈紐? $roadAddress',
      );
    }

    if (jibunAddress != null &&
        jibunAddress.isNotEmpty &&
        jibunAddress != roadAddress) {
      lines.add(
        '吏踰? $jibunAddress',
      );
    }

    if (phone != null &&
        phone.isNotEmpty) {
      lines.add(
        '?꾪솕: $phone',
      );
    }

    lines.add(
      '?꾨룄 ${place.latitude.toStringAsFixed(6)} 쨌 '
          '寃쎈룄 ${place.longitude.toStringAsFixed(6)}',
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
      fieldLabel: '?ъ뾽?λ챸',
      sourceLabel: '移댁뭅?ㅻ㏊',
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
      fieldLabel: '二쇱냼',
      sourceLabel: '移댁뭅?ㅻ㏊',
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
      fieldLabel: '?ъ뾽???곕씫泥?,
      sourceLabel: '移댁뭅?ㅻ㏊',
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
        '移댁뭅???낆껜 寃??,
      )
          : null;
    });

    if (!addressMatchesPlace) {
      _showMessage(
        '?낆껜 ?뺣낫??諛섏쁺?덉?留??좏깮??二쇱냼媛 '
            '移댁뭅???낆껜 二쇱냼? ?щ씪 吏???꾩튂瑜???ν븯吏 ?딆븯?듬땲?? '
            '二쇱냼 寃?됱씠??吏??吏곸젒 ?좏깮?쇰줈 ?꾩튂瑜??뺤씤??二쇱꽭??',
      );
      return;
    }

    _showMessage(
      '移댁뭅?ㅻ㏊ ?낆껜 ?뺣낫? ?꾩튂瑜??낅젰?쇱뿉 諛섏쁺?덉뒿?덈떎.',
    );
  }

  Future<void> _applyImportedInformation(
      _ImportedStoreInformation information,
      ) async {
    if (_submitting) {
      return;
    }

    final String resolvedName = await _resolveImportedText(
      fieldLabel: '?ъ뾽?λ챸',
      sourceLabel: information.sourceLabel,
      currentValue: _nameController.text,
      importedValue: information.name,
    );

    if (!mounted) {
      return;
    }

    final String resolvedAddress = await _resolveImportedText(
      fieldLabel: '二쇱냼',
      sourceLabel: information.sourceLabel,
      currentValue: _addressController.text,
      importedValue: information.address,
    );

    if (!mounted) {
      return;
    }

    final String resolvedPhone = await _resolveImportedText(
      fieldLabel: '?ъ뾽???곕씫泥?,
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
          ? '${information.sourceLabel} ?뺣낫瑜?諛섏쁺?덉뒿?덈떎. '
          '二쇱냼媛 蹂寃쎈릺??吏???꾩튂瑜??ㅼ떆 ?좏깮??二쇱꽭??'
          : '${information.sourceLabel} ?뺣낫瑜??낅젰?쇱뿉 諛섏쁺?덉뒿?덈떎.',
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

    // 遺덈윭??媛믪씠 ?놁쑝硫?湲곗〈 媛믪쓣 洹몃?濡??붾떎.
    if (imported.isEmpty) {
      return current;
    }

    // ?ъ슜?먭? ?꾩쭅 ?낅젰?섏? ?딆븯?ㅻ㈃ 諛붾줈 ?먮룞 ?낅젰?쒕떎.
    if (current.isEmpty) {
      return imported;
    }

    // 怨듬갚怨???뚮Ц??李⑥씠留??덈떎硫?媛숈? 媛믪쑝濡?泥섎━?쒕떎.
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
                '$fieldLabel ?뺣낫 ?뺤씤',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sourceLabel?먯꽌 遺덈윭???뺣낫媛 ?꾩옱 ?낅젰???댁슜怨??ㅻ쫭?덈떎.',
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
                        '?꾩옱 ?낅젰 ?좎?',
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
                        '$sourceLabel ?뺣낫 ?ъ슜',
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
                        '吏곸젒 ?낅젰',
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
                          labelText: '$fieldLabel 吏곸젒 ?낅젰',
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
                  child: const Text('痍⑥냼'),
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
                        '$fieldLabel???낅젰??二쇱꽭??';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      manualValue,
                    );
                  },
                  child: const Text('?뺤씤'),
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

      setState(() {
        _selectedRepresentativeImage =
            selectedImage;

        _pickingRepresentativeImage = false;
      });

      _showMessage(
        source == ImageSource.camera
            ? '珥ъ쁺???ъ쭊??????대?吏濡??좏깮?덉뒿?덈떎.'
            : '媛ㅻ윭由??ъ쭊??????대?吏濡??좏깮?덉뒿?덈떎.',
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
            ? '移대찓?쇰? ?ㅽ뻾?섏? 紐삵뻽?듬땲??'
            : '媛ㅻ윭由ъ뿉???ъ쭊??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
      );
    }
  }

  void _removeRepresentativeImage() {
    if (_submitting) {
      return;
    }

    setState(() {
      _selectedRepresentativeImage = null;
    });

    _showMessage(
      '?좏깮??????ъ쭊???쒓굅?덉뒿?덈떎.',
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
        '?꾩튂瑜?寃?됲븷 二쇱냼瑜?癒쇱? ?낅젰??二쇱꽭??',
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
          '?낅젰??二쇱냼??寃??寃곌낵瑜?李얠? 紐삵뻽?듬땲?? '
              '?곸꽭 二쇱냼瑜??쒖쇅?섍퀬 ?꾨줈紐낆씠??吏踰?二쇱냼濡??ㅼ떆 寃?됲빐 二쇱꽭??',
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
        sourceLabel: '移댁뭅??二쇱냼 寃??,
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
        '二쇱냼瑜?寃?됲븯??以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎.',
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
                '?ъ뾽???꾩튂 ?좏깮',
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
                    '痍⑥냼',
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
                    '???꾩튂 ?좏깮',
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
        '?꾨줈紐? $roadAddress',
      );
    }

    if (jibunAddress != null &&
        jibunAddress.isNotEmpty &&
        jibunAddress !=
            result.addressName) {
      lines.add(
        '吏踰? $jibunAddress',
      );
    }

    if (result.zoneNo != null) {
      lines.add(
        '?고렪踰덊샇: ${result.zoneNo}',
      );
    }

    lines.add(
      '?꾨룄 ${result.latitude.toStringAsFixed(6)} 쨌 '
          '寃쎈룄 ${result.longitude.toStringAsFixed(6)}',
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
          '湲곌린???꾩튂 ?쒕퉬?ㅺ? 爰쇱졇 ?덉뒿?덈떎.';
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
          '?꾩옱 ?꾩튂瑜??ъ슜?섎젮硫??꾩튂 沅뚰븳???덉슜??二쇱꽭??';
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
          '?꾩튂 沅뚰븳???곴뎄?곸쑝濡?嫄곕??섏뿀?듬땲?? '
              '???ㅼ젙?먯꽌 ?꾩튂 沅뚰븳???덉슜??二쇱꽭??';
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

      if (!mounted) {
        return;
      }

      setState(() {
        _currentDeviceLocation =
            _DeviceLocation(
              latitude: position!.latitude,
              longitude: position.longitude,
            );

        _currentLocationMessage =
        '?꾩옱 ?꾩튂瑜?吏???쒖옉?먯쑝濡?以鍮꾪뻽?듬땲??';
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocationMessage =
        '?꾩옱 ?꾩튂瑜??뺤씤?섎뒗 ???쒓컙???ㅻ옒 嫄몃━怨??덉뒿?덈떎.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocationMessage =
        '?꾩옱 ?꾩튂瑜??뺤씤?섏? 紐삵뻽?듬땲??';
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
        '吏???꾩튂瑜??좏깮?섍린 ?꾩뿉 '
            '?ъ뾽??二쇱냼瑜?癒쇱? ?낅젰??二쇱꽭??',
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
   * ?쒖옉 以묒떖 ?곗꽑?쒖쐞:
   *
   * 1. ?댁쟾???좏깮???ъ뾽??醫뚰몴
   * 2. 湲곌린 ?꾩옱 ?꾩튂
   * 3. 遺???쒕㈃??
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
        '?좏깮??吏???꾩튂??二쇱냼瑜??뺤씤?섏? 紐삵뻽?듬땲??',
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
        '吏?꾩뿉???좏깮???꾩튂??二쇱냼瑜??뺤씤?섏? 紐삵뻽?듬땲??',
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
   * 湲곗〈 二쇱냼媛 鍮꾩뼱 ?덉쑝硫?吏??二쇱냼? 醫뚰몴瑜?
   * 洹몃?濡??곸슜?쒕떎.
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
              sourceLabel: '吏??吏곸젒 ?좏깮',
            );
      });

      _showMessage(
        '吏?꾩뿉???좏깮??二쇱냼? ?꾩튂瑜??곸슜?덉뒿?덈떎.',
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
   * ?꾨줈紐??먮뒗 吏踰?二쇱냼媛 湲곗〈 二쇱냼? 媛숇떎硫?
   * 二쇱냼???좎??섍퀬 醫뚰몴留??곸슜?쒕떎.
   */
    if (currentAddressMatches) {
      setState(() {
        _selectedStoreLocation =
            _SelectedStoreLocation(
              latitude: result.latitude,
              longitude: result.longitude,
              address: currentAddress,
              sourceLabel: '吏??吏곸젒 ?좏깮',
            );
      });

      _showMessage(
        '?낅젰??二쇱냼? 吏???꾩튂媛 ?쇱튂?⑸땲??',
      );

      return;
    }

    /*
   * 二쇱냼媛 ?ㅻⅤ硫?湲곗〈??留뚮뱺 異⑸룎 紐⑤떖???ъ슜?쒕떎.
   */
    final String resolvedAddress =
    await _showImportedValueConflictDialog(
      fieldLabel: '二쇱냼',
      sourceLabel: '吏?꾩뿉???좏깮???꾩튂',
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
     * 吏??二쇱냼瑜??좏깮?덇굅??吏곸젒 ?낅젰媛믪씠
     * 移댁뭅??二쇱냼? 媛숈쓣 ?뚮쭔 醫뚰몴瑜??뺤젙?쒕떎.
     *
     * 湲곗〈???ㅻⅨ 二쇱냼瑜??좎??덈떎硫?醫뚰몴????ν븯吏 ?딅뒗??
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
        '吏??吏곸젒 ?좏깮',
      )
          : null;
    });

    if (!resolvedMatchesMap) {
      _showMessage(
        '?낅젰 二쇱냼瑜??좎??덉뒿?덈떎. '
            '?꾩옱 二쇱냼??留욌뒗 吏???꾩튂瑜??ㅼ떆 ?좏깮??二쇱꽭??',
      );
      return;
    }

    _showMessage(
      '吏?꾩뿉???좏깮??二쇱냼? ?꾩튂瑜??곸슜?덉뒿?덈떎.',
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
      '?좏깮??吏???꾩튂瑜?珥덇린?뷀뻽?듬땲??',
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
        '?좏깮???꾩튂??二쇱냼 ?뺣낫媛 ?놁뒿?덈떎.',
      );
      return;
    }

    final String resolvedAddress =
    await _resolveImportedText(
      fieldLabel: '二쇱냼',
      sourceLabel: sourceLabel,
      currentValue:
      _addressController.text,
      importedValue: importedAddress,
    );

    if (!mounted) {
      return;
    }

    /*
   * ?ъ슜?먭? 移댁뭅??二쇱냼 ???湲곗〈 二쇱냼??吏곸젒 ?낅젰??
   * ?좏깮?덈떎硫? ?대떦 醫뚰몴媛 ?ㅼ젣濡?洹?二쇱냼? ?쇱튂?섎뒗吏
   * 蹂댁옣?????놁쑝誘濡?醫뚰몴瑜???ν븯吏 ?딅뒗??
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
        '二쇱냼???좏깮???댁슜?쇰줈 諛섏쁺?덉뒿?덈떎. '
            '吏???꾩튂??蹂寃쎈맂 二쇱냼濡??ㅼ떆 ?뺤씤??二쇱꽭??',
      );
      return;
    }

    _showMessage(
      '$sourceLabel ?꾩튂瑜??곸슜?덉뒿?덈떎.',
    );
  }

  Future<void> _addTag() async {
    if (_submitting) {
      return;
    }

    if (_tags.length >= 8) {
      _showMessage(
        '寃???ㅼ썙?쒕뒗 理쒕? 8媛쒓퉴吏 ?깅줉?????덉뼱??',
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
        '?꾩닔 ?낅젰 ??ぉ???뺤씤??二쇱꽭??',
      );

      return;
    }

    final String? scheduleError = _schedule.validationMessage;
    if (scheduleError != null) {
      _showMessage(scheduleError);
      return;
    }

    if (!_takeoutAvailable &&
        !_dineInAvailable) {
      _showMessage(
        '?ъ옣 ?먮뒗 留ㅼ옣 ?앹궗 以??섎굹??媛?ν빐???댁슂.',
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
          '????ъ쭊???낅줈?쒗븯怨??덉뒿?덈떎.',
        );

        representativeImageUrl =
        await widget.repository
            .uploadRepresentativeImage(
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
        '?ъ뾽?μ쓣 ?깅줉?섏? 紐삵뻽?듬땲?? ?좎떆 ???ㅼ떆 ?쒕룄??二쇱꽭??',
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
        setState(() {
          _selectedRepresentativeImage = files.first;
        });

        _showMessage(
          '?댁쟾???좏깮?섎뜕 ????ъ쭊??蹂듦뎄?덉뒿?덈떎.',
        );

        return;
      }

      if (response.exception != null) {
        _showMessage(
          '?댁쟾???좏깮?섎뜕 ?대?吏瑜?蹂듦뎄?섏? 紐삵뻽?듬땲??',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '?대?吏 ?좏깮 ?뺣낫瑜?蹂듦뎄?섏? 紐삵뻽?듬땲??',
      );
    }
  }
}

